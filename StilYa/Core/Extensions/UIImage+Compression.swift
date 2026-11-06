//
//  UIImage+Compression.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import UIKit

extension UIImage {
    /// Compress image to 80% JPEG quality and max 1024px on longest side
    func compressed() -> Data? {
        let maxSize: CGFloat = 1024
        let scale = min(maxSize / max(size.width, size.height), 1.0)

        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }

        return resizedImage.jpegData(compressionQuality: 0.8)
    }

    /// Compress image to PNG (preserves transparency) and max 1024px on longest side
    func compressedPNG() -> Data? {
        let maxSize: CGFloat = 1024
        let scale = min(maxSize / max(size.width, size.height), 1.0)

        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.pngData()
    }

    /// Create thumbnail with specific size
    func thumbnail(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Alpha kanalı var mı kontrol et (arka planı kaldırılmış PNG'ler için)
    var hasAlphaChannel: Bool {
        guard let cgImage = cgImage else { return false }
        let alpha = cgImage.alphaInfo
        return alpha == .first || alpha == .last ||
               alpha == .premultipliedFirst || alpha == .premultipliedLast
    }

    /// En uzun kenar maxDimension'ı geçmeyecek şekilde orantılı küçült
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
