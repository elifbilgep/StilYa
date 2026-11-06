//
//  AppIconGenerator.swift
//  StilYa
//
//  Created for App Store submission
//

import SwiftUI
import UIKit

struct AppIconGenerator {
    static func generateAppIcon(size: CGFloat = 1024) -> UIImage? {
        let view = AppIconView(size: size)
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: size, height: size)
        controller.view.backgroundColor = .clear

        // Render to image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            controller.view.layer.render(in: context.cgContext)
        }
    }
}

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Splash Gradient Background
            LinearGradient(
                colors: [
                    Color(hex: "#1A1A1A"),
                    Color(hex: "#2D2D2D"),
                    Color(hex: "#3D3D3D")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Logo (centered)
            STLogoView(
                size: size * 0.6, // 60% of icon size
                iconColor: .white,
                backgroundColor: .white.opacity(0.15),
                showBackground: true,
                showGradient: false
            )
        }
        .frame(width: size, height: size)
    }
}

// Helper for Preview
#if DEBUG
struct AppIconPreview: View {
    @State private var generatedImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            Text("App Icon Preview")
                .font(.headline)

            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .cornerRadius(44.8) // iOS icon corner radius
                    .shadow(radius: 10)
            }

            Button("Generate Icon") {
                generatedImage = AppIconGenerator.generateAppIcon()
            }
            .buttonStyle(.borderedProminent)

            if let image = generatedImage {
                Button("Save to Photos") {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            generatedImage = AppIconGenerator.generateAppIcon()
        }
    }
}

#Preview {
    AppIconPreview()
}
#endif
