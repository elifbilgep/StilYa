//
//  CapsuleButton.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct CapsuleButton: View {
    let title: String
    let action: () -> Void
    var backgroundColor: Color = .white
    var foregroundColor: Color = .textPrimary

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(STFont.labelLarge)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: Spacing.buttonHeight)
                .background(backgroundColor)
                .clipShape(Capsule())
        }
    }
}

