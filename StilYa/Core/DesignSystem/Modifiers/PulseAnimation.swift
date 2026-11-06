//
//  PulseAnimation.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

// MARK: - Pulse Animation Modifier
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    let scaleFrom: CGFloat
    let scaleTo: CGFloat
    let opacityFrom: Double
    let opacityTo: Double
    let duration: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scaleTo : scaleFrom)
            .opacity(isPulsing ? opacityTo : opacityFrom)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - View Extension
extension View {
    /// Adds a pulsing animation (scale + opacity)
    /// - Parameters:
    ///   - scaleFrom: Starting scale (default: 1.0)
    ///   - scaleTo: Ending scale (default: 1.1)
    ///   - opacityFrom: Starting opacity (default: 0.8)
    ///   - opacityTo: Ending opacity (default: 0.4)
    ///   - duration: Animation duration (default: 1.5s)
    func pulsing(
        scaleFrom: CGFloat = 1.0,
        scaleTo: CGFloat = 1.1,
        opacityFrom: Double = 0.8,
        opacityTo: Double = 0.4,
        duration: Double = 1.5
    ) -> some View {
        modifier(PulseAnimation(
            scaleFrom: scaleFrom,
            scaleTo: scaleTo,
            opacityFrom: opacityFrom,
            opacityTo: opacityTo,
            duration: duration
        ))
    }
}
