//
//  OnboardingPaywallWrapper.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Animated wrapper for ProView shown at end of onboarding
//

import SwiftUI

struct OnboardingPaywallWrapper: View {
    let onPurchaseSuccess: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var showClose = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(appeared ? 0.3 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: appeared)

            // ProView sliding up
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                ProView(onPurchaseSuccess: onPurchaseSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
                    .overlay(alignment: .topTrailing) {
                        if showClose {
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.bgSecondary))
                            }
                            .padding(.trailing, Spacing.screenHorizontal)
                            .padding(.top, 16)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .offset(y: appeared ? 0 : UIScreen.main.bounds.height)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appeared)
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showClose = true
                }
            }
        }
    }
}
