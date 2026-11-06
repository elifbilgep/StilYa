//
//  ClosetTransitionOverlay.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 12.03.2026.
//

import SwiftUI

// MARK: - Animation Phase

enum ClosetAnimationPhase: Equatable {
    case idle
    case doorsOpening   // Kapaklar 3D açılır
    case glowExpanding  // İçinden ışık/flaş yayılır
    case whiteFlash     // Tüm ekran beyaz
    case contentReveal  // Raflar + dolap içeriği belirir
    case open           // Kullanıcı gezinir
}

// MARK: - Closet Transition Overlay

struct ClosetTransitionOverlay: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Binding var phase: ClosetAnimationPhase
    @Binding var isPresented: Bool

    private var isPro: Bool {
        RevenueCatManager.shared.isProActive
    }

    // White flash
    @State private var whiteOpacity: Double = 0

    // Content
    @State private var contentOffset: CGFloat = 24

    // Backdrop
    @State private var backdropOpacity: Double = 0

    // Circular reveal mask with blur for soft edges
    @State private var revealSize: CGFloat = 0

    // Shelf staggered reveal
    @State private var shelfVisible: [Bool] = Array(repeating: false, count: 4)

    // Track if animation already started (prevent double-fire)
    @State private var animationStarted = false

    var body: some View {
        ZStack {
            // 1) Dim backdrop
            Color.black.opacity(backdropOpacity)
                .ignoresSafeArea()

            // 2) Full-screen flash (bgPrimary for seamless transition)
            Color.bgPrimary.opacity(whiteOpacity)
                .ignoresSafeArea()

            // 3) Content after transition — radial gradient mask for soft edges
            if phase == .contentReveal || phase == .open {
                Group {
                    ClosetView(
                        shelfVisible: shelfVisible,
                        onClose: { dismissOverlay() }
                    )
                    .transition(.identity)
                }
                .offset(y: contentOffset)
                .mask(
                    Circle()
                        .frame(width: revealSize, height: revealSize)
                        .blur(radius: 50)
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !animationStarted else { return }
            animationStarted = true
            beginAnimation()
        }
        .gesture(
            DragGesture(minimumDistance: 60)
                .onEnded { value in
                    if value.translation.height > 80 && (phase == .contentReveal || phase == .open) {
                        dismissOverlay()
                    }
                }
        )
    }

    // MARK: - Animation Sequence

    private func beginAnimation() {
        // Glow is handled on the card in HomeView.
        // This overlay handles: backdrop dim → flash → content reveal.

        withAnimation(.easeIn(duration: 0.2)) {
            backdropOpacity = 0.4
        }

        // t=0.25: Full-screen flash (bgPrimary color wash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            phase = .whiteFlash

            withAnimation(.easeIn(duration: 0.15)) {
                whiteOpacity = 1.0
            }
        }

        // t=0.45: Content reveals with soft radial gradient mask
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            phase = .contentReveal
            HapticManager.shared.light()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                revealSize = UIScreen.main.bounds.height * 2.5
                contentOffset = 0
            }

            // Staggered shelf reveal
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08 + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        shelfVisible[i] = true
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                phase = .open
            }
        }
    }

    // MARK: - Dismiss

    private func dismissOverlay() {
        HapticManager.shared.light()

        withAnimation(.easeOut(duration: 0.3)) {
            revealSize = 0
            contentOffset = 16
            whiteOpacity = 0
            backdropOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Reset
            shelfVisible = Array(repeating: false, count: 4)
            animationStarted = false
            phase = .idle
            isPresented = false
        }
    }
}

// MARK: - Sparkle Particle

struct ClosetSparkleParticle: View {
    let index: Int
    let center: CGPoint
    @State private var flying = false

    private var angle: Double {
        Double(index) * 45.0 + Double.random(in: -10...10)
    }
    private var distance: CGFloat { CGFloat.random(in: 100...220) }

    private var destination: CGPoint {
        let rad = CGFloat(angle * .pi / 180)
        return CGPoint(
            x: center.x + Foundation.cos(rad) * distance,
            y: center.y + Foundation.sin(rad) * distance
        )
    }

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: CGFloat.random(in: 4...8), weight: .bold))
            .foregroundStyle(Color.proGold)
            .position(flying ? destination : center)
            .opacity(flying ? 0 : 1)
            .scaleEffect(flying ? 0.2 : 1.2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.65).delay(Double.random(in: 0...0.15))) {
                    flying = true
                }
            }
    }
}

// ClosetContentPage, ContentHangingRail, ContentShelf removed — replaced by ClosetView

#Preview {
    ClosetTransitionOverlay(
        phase: .constant(.open),
        isPresented: .constant(true)
    )
    .environmentObject(LocalizationManager.shared)
}
