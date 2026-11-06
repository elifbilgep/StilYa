//
//  SuccessBadge.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct SuccessBadge: View {
    let text: String
    var showCheckmark: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.success)
            }

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.success)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.success.opacity(0.1))
        )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SuccessBadge(text: L10n.previewThatsIt)
        SuccessBadge(text: L10n.previewSuccess, showCheckmark: false)
    }
    .padding()
    .background(Color.bgPrimary)
}
