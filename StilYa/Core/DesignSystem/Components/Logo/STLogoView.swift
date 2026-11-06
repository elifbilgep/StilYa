//
//  STLogoView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct STLogoView: View {
    let size: CGFloat
    var iconColor: Color = .white
    var backgroundColor: Color = .white.opacity(0.1)
    var showBackground: Bool = true
    var showGradient: Bool = false
    var gradientColors: [Color] = [Color.accent.opacity(0.15), Color.accentLight.opacity(0.1)]
    var animateSparkle: Bool = false

    private var cornerRadius: CGFloat {
        size * 0.3 // 30% of size
    }

    private var garmentSize: CGFloat {
        size * 0.35 // 35% of box size (küçültüldü)
    }

    private var sparkleSize: CGFloat {
        size * 0.24 // 24% of box size
    }

    var body: some View {
        ZStack {
            // Gradient Background (optional, behind everything)
            if showGradient {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            }

            // Background Box (optional)
            if showBackground {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
            }

            // Main Icon (Garment) - shifted slightly left and down
            Image(systemName: "tshirt.fill")
                .font(.system(size: garmentSize))
                .foregroundColor(iconColor)
                .offset(x: -size * 0.08, y: size * 0.05)

            // Sparkle (top-right corner) - more prominent
            Image(systemName: "sparkles")
                .font(.system(size: sparkleSize, weight: .bold))
                .foregroundColor(iconColor)
                .offset(x: size * 0.20, y: -size * 0.20)
                .modifier(SparkleAnimationModifier(animate: animateSparkle))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sparkle Animation

private struct SparkleAnimationModifier: ViewModifier {
    let animate: Bool
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        if animate {
            content
                .scaleEffect(isGlowing ? 1.08 : 0.94)
                .opacity(isGlowing ? 1.0 : 0.65)
                .shadow(color: .white.opacity(isGlowing ? 0.4 : 0), radius: isGlowing ? 4 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        isGlowing = true
                    }
                }
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Splash style (dark background)
        STLogoView(
            size: 100,
            iconColor: .white,
            backgroundColor: .white.opacity(0.1)
        )
        .background(Color.black)

        // Welcome style (light background with gradient)
        STLogoView(
            size: 100,
            iconColor: Color(hex: "#1C1917"),
            backgroundColor: Color(hex: "#1C1917").opacity(0.05),
            showGradient: true
        )
        .background(Color(hex: "#FAF9F6"))

        // Small size with gradient
        STLogoView(
            size: 60,
            iconColor: Color(hex: "#1C1917"),
            backgroundColor: Color(hex: "#1C1917").opacity(0.05),
            showGradient: true
        )
        .background(Color(hex: "#FAF9F6"))

        // No background, only gradient
        STLogoView(
            size: 80,
            iconColor: Color(hex: "#1C1917"),
            showBackground: false,
            showGradient: true
        )
        .background(Color(hex: "#FAF9F6"))
    }
    .padding()
}
