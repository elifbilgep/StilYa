//
//  OnboardingFakeProgressView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 12: Fake progress — building anticipation before paywall
//

import SwiftUI

struct OnboardingFakeProgressView: View {
    let onComplete: () -> Void

    @State private var progress: Double = 0.0
    @State private var currentPhase = 0
    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var hasCompleted = false

    // Phase config: (locKey, iconName, garmentImages)
    private let phases: [(String, String, [String])] = [
        ("onboarding.progress.creatingAvatar", "person.crop.circle.badge.checkmark", []),
        ("onboarding.progress.findingClothes", "tshirt", []),
        ("onboarding.progress.customizingApp", "slider.horizontal.3", []),
        ("onboarding.progress.preparingCloset", "cabinet", [])
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Phase Visual
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.accent.opacity(0.06), lineWidth: 2)
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.accent.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 90
                            )
                        )
                        .frame(width: 160, height: 160)

                    // Phase-specific content
                    if currentPhase == 0 {
                        avatarPhaseView
                    } else if currentPhase == 1 {
                        clothesPhaseView
                    } else if currentPhase == 2 {
                        customizingPhaseView
                    } else {
                        closetPhaseView
                    }
                }
                .frame(height: 200)

                Spacer().frame(height: 36)

                // MARK: - Message
                VStack(spacing: 8) {
                    Text(LocalizationManager.shared.localized(phases[currentPhase].0))
                        .font(STFont.displaySmall)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: currentPhase)

                    // Step dots
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i <= currentPhase ? Color.accent : Color.accent.opacity(0.15))
                                .frame(width: 6, height: 6)
                                .scaleEffect(i == currentPhase ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPhase)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer().frame(height: 48)

                // MARK: - Progress Bar
                VStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.bgSecondary)
                            .frame(height: 8)

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accent, Color.accent.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: progress)

                            // Shimmer on progress bar
                            if progress > 0.05 {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.3), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 40, height: 8)
                                    .offset(x: geometry.size.width * progress - 40)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 48)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .monospacedDigit()
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            appeared = true
            startPulse()
            startFakeProgress()
        }
    }

    // MARK: - Phase Views

    private var avatarPhaseView: some View {
        ZStack {
            Circle()
                .fill(Color.accent.opacity(0.06))
                .frame(width: 100, height: 100)

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.accent)
                .symbolEffect(.pulse, options: .repeating)
        }
    }

    private var clothesPhaseView: some View {
        HStack(spacing: -4) {
            clothesCard(systemName: "tshirt.fill", index: 0, rotation: -8, yOffset: 0)
            clothesCard(systemName: "figure.stand", index: 1, rotation: 0, yOffset: -10)
            clothesCard(systemName: "shoe.fill", index: 2, rotation: 8, yOffset: 0)
        }
    }

    private func clothesCard(systemName: String, index: Int, rotation: Double, yOffset: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgPrimary)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

            Image(systemName: systemName)
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.accent)
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .rotationEffect(.degrees(rotation))
        .offset(y: yOffset)
        .scaleEffect(appeared ? 1.0 : 0.5)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7)
                .delay(Double(index) * 0.15),
            value: appeared
        )
    }

    private var customizingPhaseView: some View {
        VStack(spacing: 10) {
            // Simulated sliders
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accent.opacity(0.15))
                        .frame(width: 80, height: 6)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accent)
                                .frame(width: CGFloat([52, 64, 40][i]), height: 6)
                        }

                    Circle()
                        .fill(Color.accent)
                        .frame(width: 10, height: 10)
                }
                .opacity(appeared ? 1.0 : 0.0)
                .offset(x: appeared ? 0 : -20)
                .animation(
                    .easeOut(duration: 0.4).delay(Double(i) * 0.12),
                    value: appeared
                )
            }
        }
    }

    private var closetPhaseView: some View {
        ZStack {
            Circle()
                .fill(Color.accent.opacity(0.06))
                .frame(width: 100, height: 100)

            Image(systemName: "cabinet")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.accent)
                .symbolEffect(.pulse, options: .repeating)
        }
    }

    // MARK: - Animations

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
            pulseScale = 1.6
        }
    }

    private func startFakeProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if progress < 0.25 {
                progress += 0.017
            } else if progress < 0.50 {
                if currentPhase < 1 {
                    withAnimation(.easeInOut(duration: 0.4)) { currentPhase = 1 }
                }
                progress += 0.015
            } else if progress < 0.75 {
                if currentPhase < 2 {
                    withAnimation(.easeInOut(duration: 0.4)) { currentPhase = 2 }
                }
                progress += 0.012
            } else if progress < 1.0 {
                if currentPhase < 3 {
                    withAnimation(.easeInOut(duration: 0.4)) { currentPhase = 3 }
                }
                progress += 0.010
            } else {
                timer.invalidate()
                guard !hasCompleted else { return }
                hasCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}
