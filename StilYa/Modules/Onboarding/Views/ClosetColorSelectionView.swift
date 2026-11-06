//
//  ClosetColorSelectionView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 24.03.2026.
//  Onboarding Step 2: Choose wardrobe color
//

import SwiftUI

struct ClosetColorSelectionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Binding var closetColor: String
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false
    @State private var scrolledOptionId: String?

    private var selectedOption: ClosetColorOption {
        ClosetColorOption(rawValue: closetColor) ?? .darkWood
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Title
                Text(L10n.onboardingClosetColorTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.sm)

                // Subtitle
                Text(L10n.onboardingClosetColorSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer()

                // Closet carousel (swipeable, center item large, sides small + faded)
                closetCarousel
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                Spacer()

                // All color circles visible (no scroll)
                colorCirclesRow
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                Spacer()

                // Continue button
                PrimaryButton(
                    title: L10n.commonContinue,
                    action: onContinue
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            scrolledOptionId = selectedOption.id
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Closet Carousel

    private var closetCarousel: some View {
        let screenWidth = UIScreen.main.bounds.width
        let itemWidth = screenWidth * 0.5
        let spacing: CGFloat = 16
        let sidePadding = (screenWidth - itemWidth) / 2

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(ClosetColorOption.allCases) { option in
                    WardrobeIllustration(
                        colorScheme: ClosetColorScheme.scheme(for: option)
                    )
                    .frame(width: 165, height: 215)
                    .frame(width: itemWidth)
                    .scrollTransition(axis: .horizontal) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1.0 : 0.6)
                            .scaleEffect(phase.isIdentity ? 1.0 : 0.75)
                    }
                    .id(option.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledOptionId)
        .safeAreaPadding(.horizontal, sidePadding)
        .frame(height: 230)
        .onChange(of: scrolledOptionId) { _, newValue in
            if let newValue, newValue != closetColor {
                withAnimation(.easeInOut(duration: 0.25)) {
                    closetColor = newValue
                }
            }
        }
    }

    // MARK: - Color Circles (2 rows, no labels)

    private var colorCirclesRow: some View {
        let allOptions = ClosetColorOption.allCases
        let topRow = Array(allOptions.prefix(5))
        let bottomRow = Array(allOptions.suffix(from: 5))

        return VStack(spacing: 14) {
            HStack(spacing: 16) {
                ForEach(topRow) { option in
                    ColorCircleButton(
                        option: option,
                        isSelected: closetColor == option.rawValue,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                closetColor = option.rawValue
                                scrolledOptionId = option.id
                            }
                        }
                    )
                }
            }
            HStack(spacing: 16) {
                ForEach(bottomRow) { option in
                    ColorCircleButton(
                        option: option,
                        isSelected: closetColor == option.rawValue,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                closetColor = option.rawValue
                                scrolledOptionId = option.id
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Color Circle Button

private struct ColorCircleButton: View {
    let option: ClosetColorOption
    let isSelected: Bool
    let onSelect: () -> Void

    private var scheme: ClosetColorScheme {
        ClosetColorScheme.scheme(for: option)
    }

    var body: some View {
        Button(action: onSelect) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [scheme.frameLight, scheme.frameMid, scheme.frameDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 30 : 24, height: isSelected ? 30 : 24)
                .overlay(
                    Circle()
                        .stroke(Color.accent, lineWidth: isSelected ? 2 : 0)
                        .padding(-3)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

#Preview {
    ClosetColorSelectionView(
        closetColor: .constant("darkWood"),
        onContinue: {}
    )
    .environmentObject(LocalizationManager.shared)
}
