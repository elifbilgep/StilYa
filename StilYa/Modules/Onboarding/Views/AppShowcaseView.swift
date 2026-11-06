//
//  AppShowcaseView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding showcase pages — each rendered as a separate step in the main flow
//

import SwiftUI

// MARK: - Page 1: Before/After Try-On

struct ShowcaseTryOnView: View {
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var showAfter = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Title
                Text(LocalizationManager.shared.localized("onboarding.showcase.tryonTitle"))
                    .font(STFont.displaySmall)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 4)

                Text(LocalizationManager.shared.localized("onboarding.showcase.tryonSubtitle"))
                    .font(STFont.bodySmall)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 16)

                // Main content area — images stacked, crossfade transition
                HStack(spacing: 12) {
                    // Images — exact same position, crossfade
                    ZStack {
                        Image("showcase-before")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLG))
                            .opacity(showAfter ? 0 : 1)

                        Image("showcase-after")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLG))
                            .opacity(showAfter ? 1 : 0)
                    }
                    .frame(maxHeight: 360)

                    // Garment boxes — right side, always visible
                    VStack(spacing: 10) {
                        ShowcaseGarmentBox(label: LocalizationManager.shared.localized("onboarding.showcase.top"), imageName: "showcase-top")
                        ShowcaseGarmentBox(label: LocalizationManager.shared.localized("onboarding.showcase.bottom"), imageName: "showcase-bottom")
                        ShowcaseGarmentBox(label: LocalizationManager.shared.localized("onboarding.showcase.shoes"), imageName: "showcase-shoes")
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: showAfter)
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer().frame(height: 16)

                // Before / After toggle
                ShowcaseBeforeAfterToggle(showAfter: $showAfter)
                    .padding(.horizontal, 60)

                Spacer()

                PrimaryButton(title: L10n.commonContinue, action: onContinue)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}


// MARK: - Page 3: Closet Showcase

struct ShowcaseClosetView: View {
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text(LocalizationManager.shared.localized("onboarding.showcase.closetTitle"))
                    .font(STFont.displaySmall)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.sm)

                Text(LocalizationManager.shared.localized("onboarding.showcase.closetSubtitle"))
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 32)

                Image("showcase-closet")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer()

                PrimaryButton(title: L10n.commonContinue, action: onContinue)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

// MARK: - Shared Components

struct ShowcaseBeforeAfterToggle: View {
    @Binding var showAfter: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { showAfter = false }
            } label: {
                Text("Before")
                    .font(STFont.labelSmall)
                    .foregroundColor(!showAfter ? .white : .textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(!showAfter ? Color.accent : Color.clear)
                    )
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) { showAfter = true }
            } label: {
                Text("After")
                    .font(STFont.labelSmall)
                    .foregroundColor(showAfter ? .white : .textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showAfter ? Color.accent : Color.clear)
                    )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.bgSecondary)
        )
    }
}

struct ShowcaseGarmentBox: View {
    let label: String
    let imageName: String

    var body: some View {
        VStack(spacing: 6) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSM))
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSM)
                        .fill(Color.bgSecondary)
                )

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }
}
