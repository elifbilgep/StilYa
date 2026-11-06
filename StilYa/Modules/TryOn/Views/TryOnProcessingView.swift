//
//  TryOnProcessingView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

struct TryOnProcessingView: View {
    let progress: Double

    // MARK: - State
    @State private var currentTipIndex = 0
    @State private var outerRotation: Double = 0
    @State private var particlePulse: Bool = false
    @State private var tipOpacity: Double = 1.0
    @State private var tipTimer: Timer?

    // MARK: - Processing Steps
    private var currentStep: ProcessingStep {
        switch progress {
        case 0..<0.15: return .analyzing
        case 0.15..<0.35: return .mapping
        case 0.35..<0.60: return .fitting
        case 0.60..<0.85: return .rendering
        case 0.85..<0.95: return .finishing
        default: return .ready
        }
    }

    private let tips: [String] = [
        L10n.tryonTipsPlainColors,
        L10n.tryonTipsAccessoryCompletes,
        L10n.tryonTipsRightSize,
        L10n.tryonTipsContrastColors,
        L10n.tryonTipsLessIsMore
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            // Floating particles
            floatingParticles

            VStack(spacing: 0) {
                // Step indicator - positioned at top
                stepIndicator
                    .padding(.top, Spacing.screenTopPadding + 20)

                Spacer()

                // Main content - vertically centered
                VStack(spacing: 0) {
                    // Main animation ring
                    mainRing
                        .padding(.bottom, 32)

                    // Status text
                    statusText
                        .padding(.bottom, 16)

                    // Progress bar
                    progressBar
                        .padding(.horizontal, 60)
                }

                Spacer()

                // Rotating tips
                tipsSection
                    .padding(.bottom, Spacing.screenVertical)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            tipTimer?.invalidate()
            tipTimer = nil
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(ProcessingStep.allCases, id: \.self) { step in
                HStack(spacing: 0) {
                    // Step dot
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 28, height: 28)

                        if step == currentStep {
                            Circle()
                                .fill(Color.proGold.opacity(0.3))
                                .frame(width: 28, height: 28)
                                .scaleEffect(1.4)
                                .opacity(0.6)
                        }

                        Image(systemName: step.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(step.rawValue <= currentStep.rawValue ? .white : .textSecondary.opacity(0.5))
                    }

                    // Connector line (not after last)
                    if step != .ready {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.proGold : Color.border)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func stepColor(for step: ProcessingStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .proGold
        } else if step == currentStep {
            return .proGold
        } else {
            return .bgSecondary
        }
    }

    // MARK: - Main Ring

    private var mainRing: some View {
        ZStack {
            // Outer dashed rotating circle
            Circle()
                .stroke(Color.proGold.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(outerRotation))

            // Track circle
            Circle()
                .stroke(Color.proGold.opacity(0.15), lineWidth: 5)
                .frame(width: 120, height: 120)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color.proGold.opacity(0.4), Color.proGold],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            // Center icon
            VStack(spacing: 4) {
                Image(systemName: currentStep.icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.proGold)
                    .contentTransition(.symbolEffect(.replace))

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.proGold)
            }
        }
    }

    // MARK: - Floating Particles

    private static let particleIcons = ["tshirt.fill", "scissors", "sparkle", "hanger", "star.fill", "wand.and.stars"]
    private static let particleSizes: [CGFloat] = [14, 16, 12, 15, 13, 17]
    private static let particleRadii: [CGFloat] = [130, 145, 125, 155, 135, 150]
    private static let particleOpacities: [Double] = [0.12, 0.10, 0.15, 0.08, 0.14, 0.11]

    private var floatingParticles: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * .pi / 3
                let radius = Self.particleRadii[i]
                Image(systemName: Self.particleIcons[i])
                    .font(.system(size: Self.particleSizes[i]))
                    .foregroundColor(.proGold.opacity(Self.particleOpacities[i]))
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
                    .opacity(particlePulse ? 1.0 : 0.4)
                    .scaleEffect(particlePulse ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.3),
                        value: particlePulse
                    )
            }
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 6) {
            Text(currentStep.title)
                .font(STFont.displaySmall)
                .foregroundColor(.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            Text(currentStep.subtitle)
                .font(STFont.bodyMedium)
                .foregroundColor(.textSecondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.bgSecondary)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.proGold.opacity(0.7), Color.proGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.proGold.opacity(0.6))

                Text(tips[currentTipIndex])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .opacity(tipOpacity)
            }

            // Tip dots
            HStack(spacing: 4) {
                ForEach(0..<tips.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentTipIndex ? Color.proGold.opacity(0.6) : Color.border)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Outer ring rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }

        // Particle pulse
        particlePulse = true

        // Tip rotation
        tipTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                tipOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                currentTipIndex = (currentTipIndex + 1) % tips.count
                withAnimation(.easeIn(duration: 0.3)) {
                    tipOpacity = 1
                }
            }
        }
    }
}

// MARK: - Processing Step

private enum ProcessingStep: Int, CaseIterable {
    case analyzing = 0
    case mapping = 1
    case fitting = 2
    case rendering = 3
    case finishing = 4
    case ready = 5

    var title: String {
        switch self {
        case .analyzing: return L10n.tryonProcessingAnalyzingPhotos
        case .mapping: return L10n.tryonProcessingMatchingGarment
        case .fitting: return L10n.tryonProcessingApplyingStyle
        case .rendering: return L10n.tryonProcessingGeneratingImage
        case .finishing: return L10n.tryonProcessingFinalTouches
        case .ready: return L10n.tryonProcessingReady
        }
    }

    var subtitle: String {
        switch self {
        case .analyzing: return L10n.tryonProcessingAnalyzingDesc
        case .mapping: return L10n.tryonProcessingMatchingDesc
        case .fitting: return L10n.tryonProcessingStyleDesc
        case .rendering: return L10n.tryonProcessingGeneratingDesc
        case .finishing: return L10n.tryonProcessingFinalDesc
        case .ready: return L10n.tryonProcessingReadyDesc
        }
    }

    var icon: String {
        switch self {
        case .analyzing: return "magnifyingglass"
        case .mapping: return "tshirt.fill"
        case .fitting: return "paintbrush.fill"
        case .rendering: return "sparkles"
        case .finishing: return "wand.and.stars"
        case .ready: return "checkmark.circle.fill"
        }
    }
}

#Preview {
    TryOnProcessingView(progress: 0.5)
}
