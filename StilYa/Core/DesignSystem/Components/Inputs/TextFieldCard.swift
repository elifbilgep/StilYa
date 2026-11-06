//
//  TextFieldCard.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct TextFieldCard: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    @State private var isSecureVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Leading Icon (optional)
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
                    .frame(width: 20)
            }

            // Text Field
            Group {
                if isSecure && !isSecureVisible {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.textSecondary))
                        .focused($isFocused)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textSecondary))
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.textPrimary)

            // Trailing Icon (for secure field toggle)
            if isSecure {
                Button(action: {
                    isSecureVisible.toggle()
                }) {
                    Image(systemName: isSecureVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: Spacing.buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusLG)
                .fill(Color.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusLG)
                        .strokeBorder(
                            isFocused ? Color.accent.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        TextFieldCard(
            placeholder: "Email",
            text: .constant(""),
            icon: "envelope.fill",
            keyboardType: .emailAddress
        )

        TextFieldCard(
            placeholder: L10n.previewPassword,
            text: .constant(""),
            icon: "lock.fill",
            isSecure: true
        )
    }
    .padding()
    .background(Color.bgPrimary)
}
