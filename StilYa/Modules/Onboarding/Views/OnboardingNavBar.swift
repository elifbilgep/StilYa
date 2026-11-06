//
//  OnboardingNavBar.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Reusable navigation bar with progress bar for onboarding steps
//

import SwiftUI

struct OnboardingNavBar: View {
    let step: OnboardingStep
    var onBack: (() -> Void)? = nil

    private var progress: CGFloat {
        guard let index = step.progressIndex else { return 0 }
        return CGFloat(index + 1) / CGFloat(step.progressTotal)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            HStack(spacing: Spacing.md) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.accent)
                            .frame(width: 36, height: 36)
                    }
                } else {
                    Spacer().frame(width: 36)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.bgSecondary)
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accent)
                            .frame(width: geometry.size.width * progress, height: 5)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 5)

                Spacer().frame(width: 36)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }
}
