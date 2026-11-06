//
//  ComboProcessingView.swift
//  StilYa
//
//  Rewritten: 2026-02-16 - SwiftUI-native animations, no Timer leak
//

import SwiftUI
import Combine

struct ComboProcessingView: View {
    let progress: Double
    let phase: ComboPhase

    @State private var outerRotation: Double = 0
    @State private var particlePulse = false
    @State private var tipIndex = 0
    @State private var tipOpacity: Double = 1.0

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

            floatingParticles

            VStack(spacing: 0) {
                phaseIndicator
                    .padding(.top, Spacing.screenTopPadding + 16)

                Spacer()

                VStack(spacing: 24) {
                    mainRing
                    phaseContent
                    progressBar
                        .padding(.horizontal, 50)
                }

                Spacer()

                tipsSection
                    .padding(.bottom, Spacing.screenVertical)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onReceive(
            Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
        ) { _ in
            rotateTip()
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    // MARK: - Phase Indicator

    private var steps: [(icon: String, label: String)] {
        var result: [(icon: String, label: String)] = []
        result.append(("sparkle", L10n.comboProcessingPreparing))
        result.append(("magnifyingglass", L10n.comboProcessingAnalyzing))
        result.append(("tshirt.fill", L10n.comboGarments))
        result.append(("wand.and.stars", L10n.comboProcessingFinalizing))
        return result
    }

    private var currentStepIndex: Int {
        switch phase {
        case .idle: return -1
        case .preparingImages: return 0
        case .analyzingGarments: return 1
        case .applyingGarments: return 2
        case .finalizing: return 3
        case .done: return steps.count // all done, past last step
        }
    }

    private var phaseIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 0) {
                    phaseStep(
                        icon: step.icon,
                        label: step.label,
                        isActive: index == currentStepIndex,
                        isDone: index < currentStepIndex
                    )

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStepIndex ? Color.proGold : Color.border)
                            .frame(height: 2)
                            .frame(maxWidth: 32)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func phaseStep(icon: String, label: String, isActive: Bool, isDone: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive || isDone ? Color.proGold : Color.bgSecondary)
                    .frame(width: 30, height: 30)

                if isActive {
                    Circle()
                        .fill(Color.proGold.opacity(0.3))
                        .frame(width: 30, height: 30)
                        .scaleEffect(1.3)
                }

                Image(systemName: isDone ? "checkmark" : icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive || isDone ? .white : .textSecondary.opacity(0.5))
            }

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isActive ? .proGold : isDone ? .textPrimary : .textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: 65)
    }

    // MARK: - Main Ring

    private var mainRing: some View {
        ZStack {
            Circle()
                .stroke(Color.proGold.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(outerRotation))

            Circle()
                .stroke(Color.proGold.opacity(0.15), lineWidth: 5)
                .frame(width: 120, height: 120)

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

            VStack(spacing: 4) {
                Image(systemName: phaseIcon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.proGold)
                    .contentTransition(.symbolEffect(.replace))

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.proGold)
            }
        }
    }

    // MARK: - Phase Content

    private var phaseContent: some View {
        VStack(spacing: 6) {
            Text(phaseTitle)
                .font(STFont.displaySmall)
                .foregroundColor(.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: phaseTitle)

            Text(phaseSubtitle)
                .font(STFont.bodyMedium)
                .foregroundColor(.textSecondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: phaseSubtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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

    // MARK: - Floating Particles

    private static let particleData: [(icon: String, size: CGFloat, radius: CGFloat, opacity: Double)] = [
        ("tshirt.fill", 14, 130, 0.12),
        ("scissors", 16, 145, 0.10),
        ("sparkle", 12, 125, 0.15),
        ("hanger", 15, 155, 0.08),
        ("star.fill", 13, 135, 0.14),
        ("wand.and.stars", 17, 150, 0.11)
    ]

    private var floatingParticles: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let data = Self.particleData[i]
                let angle = Double(i) * .pi / 3
                Image(systemName: data.icon)
                    .font(.system(size: data.size))
                    .foregroundColor(.proGold.opacity(data.opacity))
                    .offset(x: cos(angle) * data.radius, y: sin(angle) * data.radius)
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

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.proGold.opacity(0.6))

                Text(tips[tipIndex])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .opacity(tipOpacity)
            }

            HStack(spacing: 4) {
                ForEach(0..<tips.count, id: \.self) { i in
                    Circle()
                        .fill(i == tipIndex ? Color.proGold.opacity(0.6) : Color.border)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    // MARK: - Computed

    private var phaseIcon: String {
        switch phase {
        case .idle: return "hourglass"
        case .preparingImages: return "photo.stack"
        case .analyzingGarments: return "magnifyingglass"
        case .applyingGarments: return "tshirt.fill"
        case .finalizing: return "wand.and.stars"
        case .done: return "checkmark.circle.fill"
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .idle: return L10n.comboProcessingPreparing
        case .preparingImages: return L10n.comboProcessingPreparing
        case .analyzingGarments: return L10n.comboProcessingAnalyzing
        case .applyingGarments(let name, _, _): return L10n.comboProcessingApplyingGarment(name)
        case .finalizing: return L10n.comboProcessingFinalizing
        case .done: return L10n.comboProcessingReady
        }
    }

    private var phaseSubtitle: String {
        switch phase {
        case .idle: return L10n.comboProcessingPreparingDesc
        case .preparingImages: return L10n.comboProcessingPreparingDesc
        case .analyzingGarments(let name): return L10n.comboProcessingAnalyzingDesc(name)
        case .applyingGarments(_, let index, let total): return L10n.comboProcessingGarmentDesc(index, total)
        case .finalizing: return L10n.comboProcessingFinalizingDesc
        case .done: return L10n.comboProcessingReadyDesc
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }
        particlePulse = true
    }

    private func rotateTip() {
        withAnimation(.easeOut(duration: 0.3)) { tipOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            tipIndex = (tipIndex + 1) % tips.count
            withAnimation(.easeIn(duration: 0.3)) { tipOpacity = 1 }
        }
    }
}

#Preview("Preparing") {
    ComboProcessingView(
        progress: 0.1,
        phase: .preparingImages
    )
}

#Preview("Analyzing") {
    ComboProcessingView(
        progress: 0.2,
        phase: .analyzingGarments(name: "Üst, Alt")
    )
}

#Preview("Applying") {
    ComboProcessingView(
        progress: 0.5,
        phase: .applyingGarments(name: "Üst, Alt", index: 3, total: 4)
    )
}

#Preview("Finalizing") {
    ComboProcessingView(
        progress: 0.9,
        phase: .finalizing
    )
}
