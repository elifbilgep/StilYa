//
//  PrimaryButton.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }

                Text(title)
                    .font(STFont.button)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                    .fill(isDisabled ? Color.textSecondary.opacity(0.3) : Color.textPrimary)
            )
        }
        .disabled(isDisabled || isLoading)
    }
}
