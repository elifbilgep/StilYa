//
//  SecondaryButton.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(STFont.button)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Spacing.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                        .stroke(Color.textPrimary, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                .fill(Color.white)
                        )
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: L10n.previewSaveToGallery) {}
        SecondaryButton(title: L10n.previewDisabled, isDisabled: true) {}
    }
    .padding()
    .background(Color.bgPrimary)
}
