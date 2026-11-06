//
//  ClosetCardView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 12.03.2026.
//

import SwiftUI

struct ClosetCardView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    var leftDoorRotation: Double = 0
    var rightDoorRotation: Double = 0
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        VStack(spacing: 6) {
            // Wardrobe illustration
            WardrobeIllustration(
                leftDoorRotation: leftDoorRotation,
                rightDoorRotation: rightDoorRotation,
                colorScheme: colorScheme
            )
            .frame(width: 165, height: 215)

            // Label
            Text(L10n.closetTitle)
                .font(STFont.labelMedium)
                .foregroundColor(.textPrimary)
        }
    }
}

// MARK: - Wardrobe Illustration (SwiftUI Shapes)

struct WardrobeIllustration: View {
    var leftDoorRotation: Double = 0
    var rightDoorRotation: Double = 0
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // -- Dark interior (visible when doors open)
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [colorScheme.interior, colorScheme.interiorDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Interior details (visible behind doors)
                VStack(spacing: 0) {
                    Spacer().frame(height: h * 0.22)
                    // Hanging rail
                    HangingRail(width: w * 0.6, colorScheme: colorScheme)
                    Spacer()
                    // Shelf lines
                    ShelfLine(colorScheme: colorScheme)
                        .padding(.horizontal, 16)
                    Spacer()
                    ShelfLine(colorScheme: colorScheme)
                        .padding(.horizontal, 16)
                    Spacer().frame(height: h * 0.14)
                }

                // -- Wardrobe body (frame)
                WardrobeFrame(w: w, h: h, colorScheme: colorScheme)

                // -- Crown molding (behind doors)
                CrownMolding(w: w, colorScheme: colorScheme)
                    .position(x: w / 2, y: 10)

                // -- Left door
                ClosetDoor(isLeft: true, w: w, h: h, colorScheme: colorScheme)
                    .rotation3DEffect(
                        .degrees(leftDoorRotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.4
                    )
                    .zIndex(1)

                // -- Right door
                ClosetDoor(isLeft: false, w: w, h: h, colorScheme: colorScheme)
                    .rotation3DEffect(
                        .degrees(rightDoorRotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.4
                    )
                    .zIndex(1)

                // -- Feet
                WardrobeFeet(w: w, h: h, colorScheme: colorScheme)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Wardrobe Frame

private struct WardrobeFrame: View {
    let w: CGFloat
    let h: CGFloat
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        ZStack {
            // Outer body fill (wood)
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.frameLight,
                            colorScheme.frameMid,
                            colorScheme.frameDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 6)

            // Interior cutout (dark)
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [colorScheme.interior, colorScheme.interiorDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 14)

            // Frame border (outer edge highlight)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            colorScheme.border.opacity(0.6),
                            colorScheme.shelf.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 6)

            // Side edge shadows (depth)
            HStack(spacing: 0) {
                // Left edge shadow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.15), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4)

                Spacer()

                // Right edge shadow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 6)

            // Top edge light reflection
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
                .padding(.horizontal, 8)
                .position(x: w / 2, y: 9)
        }
    }
}

// MARK: - Closet Door

private struct ClosetDoor: View {
    let isLeft: Bool
    let w: CGFloat
    let h: CGFloat
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    private var doorWidth: CGFloat { (w - 22) / 2 }
    private var doorHeight: CGFloat { h - 28 }

    var body: some View {
        ZStack {
            // Door base panel
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.doorLight,
                            colorScheme.doorMid,
                            colorScheme.frameMid,
                            colorScheme.doorDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Raised panel inset (upper)
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.panelLight,
                            colorScheme.panelDark
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.horizontal, 7)
                .padding(.top, 8)
                .padding(.bottom, doorHeight * 0.52)

            // Raised panel border (upper)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .padding(.horizontal, 7)
                .padding(.top, 8)
                .padding(.bottom, doorHeight * 0.52)

            // Raised panel inset (lower)
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.panelLight,
                            colorScheme.panelDark
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.horizontal, 7)
                .padding(.top, doorHeight * 0.54)
                .padding(.bottom, 8)

            // Raised panel border (lower)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .padding(.horizontal, 7)
                .padding(.top, doorHeight * 0.54)
                .padding(.bottom, 8)

            // Wood grain texture
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black.opacity(Double.random(in: 0.02...0.05)))
                        .frame(height: 0.5)
                        .padding(.horizontal, 9)
                        .offset(x: CGFloat.random(in: -2...2))
                    Spacer().frame(height: CGFloat(i % 2 == 0 ? 14 : 18))
                }
            }
            .padding(.vertical, 6)

            // Door edge highlight (left side light)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(isLeft ? 0.1 : 0.04))
                    .frame(width: 1.5)
                Spacer()
                Rectangle()
                    .fill(Color.black.opacity(isLeft ? 0.04 : 0.1))
                    .frame(width: 1)
            }
            .padding(.vertical, 2)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Handle (brass knob with detail)
            ZStack {
                // Knob shadow
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 9, height: 9)
                    .offset(x: 0, y: 1)

                // Knob base
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                colorScheme.brassLight,
                                colorScheme.brassLight.opacity(0.9),
                                colorScheme.brass,
                                colorScheme.brass.opacity(0.7)
                            ],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 5
                        )
                    )
                    .frame(width: 8, height: 8)

                // Knob highlight
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3, height: 3)
                    .offset(x: -1, y: -1)

                // Keyhole
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(colorScheme.keyhole)
                    .frame(width: 2, height: 3.5)
                    .offset(y: 5.5)
            }
            .offset(x: isLeft ? doorWidth / 2 - 11 : -doorWidth / 2 + 11, y: 2)
        }
        .frame(width: doorWidth, height: doorHeight)
        .shadow(color: .black.opacity(0.08), radius: 2, x: isLeft ? -1 : 1, y: 0)
        .position(
            x: isLeft ? 11 + doorWidth / 2 : w - 11 - doorWidth / 2,
            y: h / 2 + 1
        )
    }
}

// MARK: - Crown Molding

private struct CrownMolding: View {
    let w: CGFloat
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        ZStack {
            // Shadow under molding
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.1))
                .frame(width: w + 2, height: 10)
                .offset(y: 2)

            // Main bar
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.crown,
                            colorScheme.frameLight,
                            colorScheme.frameMid
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w + 2, height: 10)

            // Top edge highlight
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: w - 4, height: 1)
                .offset(y: -3.5)

            // Bottom lip
            Rectangle()
                .fill(colorScheme.frameDark)
                .frame(width: w, height: 1.5)
                .offset(y: 4)
        }
    }
}

// MARK: - Wardrobe Feet

private struct WardrobeFeet: View {
    let w: CGFloat
    let h: CGFloat
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        HStack(spacing: w - 40) {
            Foot(colorScheme: colorScheme)
            Foot(colorScheme: colorScheme)
        }
        .position(x: w / 2, y: h - 2)
    }
}

private struct Foot: View {
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.12))
                .frame(width: 16, height: 7)
                .offset(y: 1)

            // Foot body
            RoundedRectangle(cornerRadius: 2.5)
                .fill(
                    LinearGradient(
                        colors: [colorScheme.foot, colorScheme.footDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 14, height: 7)

            // Highlight
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 10, height: 1)
                .offset(y: -2)
        }
    }
}

// MARK: - Hanging Rail

private struct HangingRail: View {
    let width: CGFloat
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        VStack(spacing: 2) {
            // Rail with brackets
            ZStack {
                // Rail shadow
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: width, height: 2.5)
                    .offset(y: 1)

                // Rail
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                colorScheme.brassLight.opacity(0.9),
                                colorScheme.brass,
                                colorScheme.brassLight.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 2)

                // Rail highlight
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: width - 8, height: 0.8)
                    .offset(y: -0.5)
            }

            // Small hanger silhouettes
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HangerShape()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                        .frame(width: 12, height: 8)
                }
            }
        }
    }
}

struct HangerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midX
        let top = rect.minY
        let bottom = rect.maxY

        // Hook
        path.move(to: CGPoint(x: mid, y: top))
        path.addLine(to: CGPoint(x: mid, y: top + 2))

        // Shoulders
        path.move(to: CGPoint(x: rect.minX, y: bottom))
        path.addLine(to: CGPoint(x: mid, y: top + 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))

        return path
    }
}

// MARK: - Shelf Line

private struct ShelfLine: View {
    var colorScheme: ClosetColorScheme = .darkWoodScheme

    var body: some View {
        ZStack {
            // Shelf shadow
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(height: 2)
                .offset(y: 1.5)

            // Shelf surface
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme.shelf.opacity(0.7),
                            colorScheme.foot.opacity(0.5),
                            colorScheme.shelf.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2.5)

            // Shelf highlight
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
                .offset(y: -0.8)
        }
    }
}

#Preview {
    VStack {
        ClosetCardView()
            .environmentObject(LocalizationManager.shared)
    }
    .padding()
    .background(Color.bgPrimary)
}
