//
//  StepIndicator.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        Text("ADIM \(currentStep)/\(totalSteps)")
            .font(.system(size: 11, weight: .semibold))
            .tracking(2) // Letter spacing
            .foregroundColor(.textSecondary)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        StepIndicator(currentStep: 1, totalSteps: 2)
        StepIndicator(currentStep: 2, totalSteps: 3)
    }
    .padding()
    .background(Color.bgPrimary)
}
