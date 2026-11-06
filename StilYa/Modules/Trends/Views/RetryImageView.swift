//
//  RetryImageView.swift
//  StilYa
//

import SwiftUI

/// URLSession-based image view with automatic retry (replaces unreliable AsyncImage)
struct RetryImageView: View {
    let url: String

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var failed = false
    @State private var retryId = UUID()

    var body: some View {
        ZStack {
            // Background — always fills the parent frame
            Color.bgSecondary

            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .tint(.accent)
            } else {
                // Failed — tap to retry
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(.accent.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        retryId = UUID()
                    }
            }
        }
        .clipped()
        .task(id: retryId) {
            guard loadedImage == nil else { return }
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageUrl = URL(string: url) else {
            isLoading = false
            failed = true
            return
        }

        isLoading = true
        failed = false

        for attempt in 0..<3 {
            do {
                let (data, response) = try await URLSession.shared.data(from: imageUrl)
                if Task.isCancelled { return }
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }
                loadedImage = image
                isLoading = false
                return
            } catch {
                if Task.isCancelled { return }
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 500_000_000)
                    if Task.isCancelled { return }
                }
            }
        }

        isLoading = false
        failed = true
    }
}
