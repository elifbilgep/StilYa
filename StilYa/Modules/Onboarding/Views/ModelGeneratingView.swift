//
//  ModelGeneratingView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 12.03.2026.
//  AI model photo generation progress screen
//

import SwiftUI

struct ModelGeneratingView: View {
    let progress: Double
    var selfieImage: UIImage?

    @State private var showStep1 = false
    @State private var showStep2 = false
    @State private var showStep3 = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                Text(L10n.modelPhotoGeneratingTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.modelPhotoGeneratingSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Selfie preview (small)
                if let selfie = selfieImage {
                    Image(uiImage: selfie)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.accent, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }

                Spacer().frame(height: 48)

                // Progress
                VStack(spacing: Spacing.sm) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.bgSecondary)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accent)
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(progress * 100))%")
                        .font(STFont.labelSmall)
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer().frame(height: Spacing.xl)

                // Info steps
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if showStep1 {
                        InfoStepRow(icon: "face.smiling", text: L10n.modelPhotoStepFaceAnalysis)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if showStep2 {
                        InfoStepRow(icon: "person.fill", text: L10n.modelPhotoStepBodyGeneration)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if showStep3 {
                        InfoStepRow(icon: "paintpalette.fill", text: L10n.modelPhotoStepSkinTone)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusMD)
                        .fill(Color.bgSecondary)
                )
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer()
            }
        }
        .task {
            await animateSteps()
        }
    }

    @MainActor
    private func animateSteps() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        withAnimation(.easeOut(duration: 0.6)) { showStep1 = true }

        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
        withAnimation(.easeOut(duration: 0.6)) { showStep2 = true }

        try? await Task.sleep(nanoseconds: 7_000_000_000) // 7s
        withAnimation(.easeOut(duration: 0.6)) { showStep3 = true }
    }
}

private struct InfoStepRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.success)
                .frame(width: 24)
            Text(text)
                .font(STFont.bodyMedium)
                .foregroundColor(.textPrimary)
        }
    }
}
