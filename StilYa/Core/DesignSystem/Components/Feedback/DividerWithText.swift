//
//  DividerWithText.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct DividerWithText: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Rectangle()
                .fill(Color(hex: "#DDDBD5"))
                .frame(height: 1)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .fixedSize()

            Rectangle()
                .fill(Color(hex: "#DDDBD5"))
                .frame(height: 1)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        DividerWithText(text: "veya")
        DividerWithText(text: "ya da")
    }
    .padding()
    .background(Color.bgPrimary)
}
