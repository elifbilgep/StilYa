//
//  PendingModelResultSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//  Shows the model photo generated from onboarding selfie after Pro purchase.
//

import SwiftUI

struct PendingModelResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage?

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.success)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.5)

                // Title
                Text(L10n.pendingModelReadyTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                // Subtitle
                Text(L10n.pendingModelReadySubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)

                // Model photo preview
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        .padding(.horizontal, 40)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                }

                Spacer()

                // Continue button
                PrimaryButton(
                    title: L10n.commonContinue,
                    action: { dismiss() }
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
