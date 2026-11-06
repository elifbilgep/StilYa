//
//  LinkPreviewHelper.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 26.12.2025.
//  Adapted from EarnIt project
//

import Foundation
import LinkPresentation
import UIKit
import Observation

@Observable
@MainActor
class LinkPreviewHelper {
    var isLoading = false
    var error: String?

    private var currentTask: Task<ProductLinkMetadata?, Never>?

    // Known short link domains
    private let shortLinkDomains = ["ty.gl", "amzn.to", "a.co", "bit.ly", "tinyurl.com", "goo.gl"]

    /// Fetches metadata from a product URL (title, image, price info)
    func fetchMetadata(from urlString: String) async -> ProductLinkMetadata? {
        // Cancel previous task if still running
        currentTask?.cancel()

        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https" else {
            error = "Geçersiz URL"
            return nil
        }

        isLoading = true
        error = nil

        // Check if it's a short link and expand it
        var finalURLString = urlString
        if isShortLink(urlString) {
            #if DEBUG
            print("🔍 [LinkPreview] Detected short link: \(urlString)")
            #endif
            if let expandedURL = await expandShortURL(urlString) {
                finalURLString = expandedURL
                #if DEBUG
                print("✅ [LinkPreview] Short link expanded: \(urlString) → \(finalURLString)")
                #endif
            } else {
                #if DEBUG
                print("❌ [LinkPreview] Failed to expand short link: \(urlString)")
                #endif
            }
        } else {
            #if DEBUG
            print("📎 [LinkPreview] Regular link: \(urlString)")
            #endif
        }

        // Create new task and track it
        let task = Task<ProductLinkMetadata?, Never> {
            // Create new instance for each fetch (LPMetadataProvider is one-shot)
            let metadataProvider = LPMetadataProvider()

            // Use final URL (expanded if it was a short link)
            guard let finalURL = URL(string: finalURLString) else {
                return nil
            }

            do {
                #if DEBUG
                print("🌐 [LinkPreview] Fetching metadata from: \(finalURL)")
                #endif
                let metadata = try await metadataProvider.startFetchingMetadata(for: finalURL)

                // Check if task was cancelled
                guard !Task.isCancelled else {
                    return nil
                }

                // Extract title (product name)
                let title = metadata.title
                let brand = extractBrand(from: finalURLString)

                // Extract image
                var image: UIImage?
                if let imageProvider = metadata.imageProvider {
                    image = try? await loadImage(from: imageProvider)
                }

                // Extract price from title or description (best effort)
                let price = extractPrice(from: title, or: metadata.url?.absoluteString)

                #if DEBUG
                print("📝 [LinkPreview] Title: \(title ?? "nil"), Brand: \(brand ?? "nil"), Image: \(image != nil ? "✅" : "❌"), Price: \(price.map { String($0) } ?? "nil")")
                #endif

                // Check again after async operation
                guard !Task.isCancelled else {
                    return nil
                }

                return ProductLinkMetadata(
                    title: title,
                    brand: brand,
                    price: price,
                    image: image,
                    url: urlString
                )
            } catch {
                // Don't set error if task was cancelled
                guard !Task.isCancelled else {
                    return nil
                }

                #if DEBUG
                print("❌ [LinkPreview] Metadata fetch error: \(error)")
                #endif
                self.error = error.localizedDescription
                return nil
            }
        }

        currentTask = task
        let result = await task.value

        isLoading = false
        return result
    }

    /// Loads UIImage from LPLinkMetadata's image provider
    private func loadImage(from provider: NSItemProvider) async throws -> UIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { (image, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image as? UIImage {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Extract brand name from URL domain
    private func extractBrand(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }

        // Remove www. and .com/.tr etc.
        let cleaned = host
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: ".").first

        // Capitalize first letter
        return cleaned?.capitalized
    }

    /// Extract price from title or URL (best effort)
    private func extractPrice(from title: String?, or urlString: String?) -> Double? {
        let sources = [title, urlString].compactMap { $0 }

        for source in sources {
            // Try to find price patterns (₺, TL, numbers)
            let patterns = [
                "₺\\s*([0-9]+[.,]?[0-9]*)",  // ₺299 or ₺299.99
                "([0-9]+[.,]?[0-9]*)\\s*₺",  // 299₺
                "([0-9]+[.,]?[0-9]*)\\s*TL", // 299 TL
                "([0-9]+[.,]?[0-9]*)\\s*TRY" // 299 TRY
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
                   let range = Range(match.range(at: 1), in: source) {
                    let priceString = String(source[range])
                        .replacingOccurrences(of: ",", with: ".")
                        .replacingOccurrences(of: " ", with: "")

                    if let price = Double(priceString) {
                        return price
                    }
                }
            }
        }

        return nil
    }

    /// Check if URL is a short link
    private func isShortLink(_ urlString: String) -> Bool {
        return shortLinkDomains.contains { urlString.contains($0) }
    }

    /// Expand short URL to final destination (follows entire redirect chain)
    private func expandShortURL(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ [LinkPreview] Invalid URL for expansion: \(urlString)")
            #endif
            return nil
        }

        do {
            #if DEBUG
            print("🔄 [LinkPreview] Following redirect chain from: \(url)")
            #endif

            // Use URLSession that follows redirects automatically
            let configuration = URLSessionConfiguration.default
            configuration.httpMaximumConnectionsPerHost = 1
            let session = URLSession(configuration: configuration)

            var request = URLRequest(url: url)
            request.httpMethod = "GET"  // Use GET instead of HEAD to ensure redirects are followed
            request.timeoutInterval = 10

            let (_, response) = try await session.data(for: request)

            // Get final URL after ALL redirects
            if let httpResponse = response as? HTTPURLResponse {
                if let finalURL = httpResponse.url?.absoluteString {
                    #if DEBUG
                    print("🎯 [LinkPreview] Final URL after all redirects: \(finalURL)")
                    #endif

                    // Extract actual URL from tracking parameters if exists
                    if let extractedURL = extractRedirectURL(from: finalURL) {
                        return extractedURL
                    }

                    return finalURL
                }
            }

            return nil
        } catch {
            #if DEBUG
            print("❌ [LinkPreview] Failed to expand short URL: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Extract actual URL from tracking parameters (e.g., adjust_redirect)
    private func extractRedirectURL(from urlString: String) -> String? {
        guard let urlComponents = URLComponents(string: urlString) else { return nil }

        // Check for common redirect parameters
        let redirectParams = ["adjust_redirect", "redirect", "url", "target", "link"]

        for param in redirectParams {
            if let redirectValue = urlComponents.queryItems?.first(where: { $0.name == param })?.value,
               let decodedURL = redirectValue.removingPercentEncoding {
                // Check if it's a valid http/https URL
                if isValidURL(decodedURL) {
                    return decodedURL
                }
            }
        }

        return nil
    }

    /// Check if string is a valid http/https URL
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return false
        }
        return true
    }
}

// MARK: - Product Link Metadata Model

struct ProductLinkMetadata {
    let title: String?      // Product name
    let brand: String?      // Extracted from URL
    let price: Double?      // Extracted from title/URL
    let image: UIImage?     // Product image
    let url: String         // Original URL

    var isValid: Bool {
        title != nil || brand != nil || image != nil
    }
}
