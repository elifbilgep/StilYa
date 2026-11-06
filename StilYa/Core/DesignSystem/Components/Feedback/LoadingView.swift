//
//  LoadingView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

struct LoadingView: View {
    let message: String
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Rotating rings animation
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .trim(from: 0, to: 0.6)
                        .stroke(
                            Color.textPrimary.opacity(0.1 + Double(index) * 0.15),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                        .rotationEffect(.degrees(rotation + Double(index * 120)))
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text(message)
                .font(STFont.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
        )
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        LoadingView(message: L10n.previewProcessingPhoto)
    }
}
