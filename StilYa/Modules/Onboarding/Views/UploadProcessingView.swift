//
//  UploadProcessingView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 5.01.2026.
//  Upload model photo to Firebase with progress
//

import SwiftUI

struct UploadProcessingView: View {
    let image: UIImage
    let onComplete: () -> Void
    var onError: ((String) -> Void)?

    @State private var progress: Double = 0.0
    @State private var currentStep: String = L10n.onboardingProcessingPreparing
    @State private var showStep1 = false
    @State private var showStep2 = false
    @State private var showStep3 = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Title
                Text(L10n.onboardingProcessingTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Spacing.sm)

                // Description
                Text(L10n.onboardingProcessingSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Progress info
                VStack(spacing: Spacing.sm) {
                    Text(currentStep)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.textSecondary)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.bgSecondary)
                                .frame(height: 8)

                            // Progress fill
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

                // Info card with progressive rows
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if showStep1 {
                        InfoRow(icon: "lock.shield.fill", text: L10n.onboardingProcessingEncryptingInfo)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if showStep2 {
                        InfoRow(icon: "icloud.and.arrow.up", text: L10n.onboardingProcessingUploadingInfo)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if showStep3 {
                        InfoRow(icon: "checkmark.circle.fill", text: L10n.onboardingProcessingPrivateInfo)
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
            await simulateUpload()
        }
    }

    // MARK: - Methods

    @MainActor
    private func simulateUpload() async {
        // Step 1: Preparing (20%)
        currentStep = L10n.onboardingProcessingPreparing
        progress = 0.2
        withAnimation(.easeOut(duration: 0.5)) {
            showStep1 = true
        }
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Step 2: Encrypting (50%)
        currentStep = L10n.onboardingProcessingEncrypting
        progress = 0.5
        withAnimation(.easeOut(duration: 0.5)) {
            showStep2 = true
        }
        try? await Task.sleep(nanoseconds: 800_000_000)

        // Step 3: Uploading (90%)
        currentStep = L10n.onboardingProcessingUploading
        progress = 0.9
        withAnimation(.easeOut(duration: 0.5)) {
            showStep3 = true
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Step 4: Complete (100%)
        currentStep = L10n.onboardingProcessingCompleting
        progress = 1.0
        try? await Task.sleep(nanoseconds: 500_000_000)

        #if DEBUG
        print("✅ [UploadProcessing] Upload simulation complete")
        #endif
        onComplete()
    }
}

// MARK: - Info Row

private struct InfoRow: View {
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

#Preview {
    UploadProcessingView(
        image: UIImage(systemName: "person.fill")!,
        onComplete: {},
        onError: { _ in }
    )
}
