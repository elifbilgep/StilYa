//
//  DrawerCardView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import SwiftUI

struct DrawerCardView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    var drawer1Tilt: Double = 0
    var drawer2Tilt: Double = 0
    var drawer3Tilt: Double = 0
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        VStack(spacing: 6) {
            DrawerIllustration(
                drawer1Tilt: drawer1Tilt,
                drawer2Tilt: drawer2Tilt,
                drawer3Tilt: drawer3Tilt,
                colorScheme: colorScheme
            )
            .frame(height: 100)
            .frame(maxWidth: .infinity)

            Text(L10n.closetTitle)
                .font(STFont.labelMedium)
                .foregroundColor(.textPrimary)
        }
    }
}

// MARK: - Drawer Illustration

private struct DrawerIllustration: View {
    var drawer1Tilt: Double
    var drawer2Tilt: Double
    var drawer3Tilt: Double
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width   // ~160
            let h = geo.size.height  // ~120

            let topH: CGFloat = 6
            let footH: CGFloat = 8
            let frameT: CGFloat = 5

            let bodyY = topH
            let bodyH = h - topH - footH

            let innerY = bodyY + frameT
            let innerH = bodyH - frameT * 2
            let innerW = w - frameT * 2

            let gap: CGFloat = 2
            let dH = (innerH - gap * 2) / 3
            let dW = innerW

            let d1Y = innerY
            let d2Y = innerY + dH + gap
            let d3Y = innerY + (dH + gap) * 2

            ZStack(alignment: .topLeading) {
                // 1. BODY FRAME
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [colorScheme.frameMid, colorScheme.frameDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: w, height: bodyH)
                    .offset(y: bodyY)

                // Frame border
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                colorScheme.border.opacity(0.5),
                                colorScheme.shelf.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .frame(width: w, height: bodyH)
                    .offset(y: bodyY)

                // 2. INTERIOR (dark, visible when drawers tilt)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [colorScheme.interior, colorScheme.interior.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: dW, height: innerH)
                    .offset(x: frameT, y: innerY)

                // Interior shelf dividers
                ForEach(0..<2, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: dW - 4, height: 0.5)
                        .offset(
                            x: frameT + 2,
                            y: d1Y + dH * CGFloat(i + 1) + gap * CGFloat(i) + gap * 0.5
                        )
                }

                // Folded clothes silhouettes (visible when open)
                clothesSilhouette(y: d1Y + 3, offset: 8)
                    .opacity(min(drawer1Tilt / 20, 0.5))
                clothesSilhouette(y: d2Y + 3, offset: -5)
                    .opacity(min(drawer2Tilt / 20, 0.5))
                clothesSilhouette(y: d3Y + 3, offset: 12)
                    .opacity(min(drawer3Tilt / 20, 0.5))

                // 3. DRAWER FACES (slide out = offset down, higher z = front)
                // Drawer 1 (back-most)
                drawerFace(width: dW, height: dH)
                    .offset(x: frameT, y: d1Y + drawer1Tilt * 0.5)
                    .shadow(color: .black.opacity(drawer1Tilt > 0 ? 0.15 : 0), radius: 3, y: 2)
                    .zIndex(1)

                // Drawer 2 (middle)
                drawerFace(width: dW, height: dH)
                    .offset(x: frameT, y: d2Y + drawer2Tilt * 0.5)
                    .shadow(color: .black.opacity(drawer2Tilt > 0 ? 0.15 : 0), radius: 3, y: 2)
                    .zIndex(2)

                // Drawer 3 (front-most)
                drawerFace(width: dW, height: dH)
                    .offset(x: frameT, y: d3Y + drawer3Tilt * 0.5)
                    .shadow(color: .black.opacity(drawer3Tilt > 0 ? 0.15 : 0), radius: 3, y: 2)
                    .zIndex(3)

                // 4. TOP SURFACE (slight overhang)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [colorScheme.doorLight.opacity(0.9), colorScheme.frameMid],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: w + 4, height: topH)

                    // Top highlight
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: w, height: 0.5)
                        .offset(y: -topH / 2 + 0.5)

                    // Underside shadow
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: w + 2, height: 1)
                        .offset(y: topH / 2)
                }
                .offset(x: -2)

                // 5. FRAME SIDE EDGES
                Rectangle()
                    .fill(colorScheme.doorLight.opacity(0.3))
                    .frame(width: 1.5, height: bodyH - 2)
                    .offset(x: 0.5, y: bodyY + 1)

                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 1.5, height: bodyH - 2)
                    .offset(x: w - 2, y: bodyY + 1)

                // Bottom frame bar (on top of drawers to clip overflow)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [colorScheme.frameMid, colorScheme.frameDark],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: w - 2, height: frameT)
                    .offset(x: 1, y: bodyY + bodyH - frameT)
                    .zIndex(4)

                // 6. FEET
                HStack {
                    drawerFoot
                    Spacer()
                    drawerFoot
                }
                .padding(.horizontal, 14)
                .offset(y: h - footH)
                .zIndex(4)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: - Drawer Face

    private func drawerFace(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Face base
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [colorScheme.doorLight, colorScheme.frameMid],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: width, height: height)

            // Raised panel
            RoundedRectangle(cornerRadius: 1.5)
                .fill(LinearGradient(
                    colors: [colorScheme.foot, colorScheme.frameMid.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: width - 8, height: height - 5)

            // Panel border
            RoundedRectangle(cornerRadius: 1.5)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
                .frame(width: width - 8, height: height - 5)

            // Top bevel highlight
            Rectangle()
                .fill(colorScheme.doorLight.opacity(0.5))
                .frame(width: width - 2, height: 0.5)
                .offset(y: -height / 2 + 0.5)

            // Bottom shadow line
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(width: width - 2, height: 0.5)
                .offset(y: height / 2 - 0.5)

            // Brass knob (center)
            ZStack {
                // Knob shadow
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .offset(y: 0.5)

                // Knob
                Circle()
                    .fill(RadialGradient(
                        colors: [colorScheme.brassLight, colorScheme.brass, colorScheme.brass.opacity(0.7)],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 5
                    ))
                    .frame(width: 7, height: 7)

                // Highlight
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: -1, y: -1)
            }
        }
    }

    // MARK: - Clothes Silhouettes

    private func clothesSilhouette(y: CGFloat, offset xOff: CGFloat) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.12))
                .frame(width: 18, height: 10)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.08))
                .frame(width: 14, height: 10)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.1))
                .frame(width: 16, height: 10)
        }
        .offset(x: 20 + xOff, y: y)
    }

    // MARK: - Foot

    private var drawerFoot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.08))
                .frame(width: 14, height: 7)
                .offset(y: 1)

            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [colorScheme.frameMid, colorScheme.frameDark],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 12, height: 7)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        DrawerCardView()
            .padding(.horizontal, 22)
            .environmentObject(LocalizationManager.shared)

        DrawerCardView(drawer1Tilt: 25, drawer2Tilt: 25, drawer3Tilt: 25)
            .padding(.horizontal, 22)
            .environmentObject(LocalizationManager.shared)
    }
    .padding(.vertical)
    .background(Color.bgPrimary)
}
