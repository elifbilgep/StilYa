//
//  OutlineButton.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct OutlineButton: View {
    let title: String
    let action: () -> Void
    var borderColor: Color = .accent
    var foregroundColor: Color = .textPrimary
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(STFont.labelLarge)
                .foregroundColor(isDisabled ? foregroundColor.opacity(0.5) : foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: Spacing.buttonHeight)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                        .stroke(isDisabled ? borderColor.opacity(0.3) : borderColor, lineWidth: 1.5)
                )
        }
        .disabled(isDisabled)
    }
}

