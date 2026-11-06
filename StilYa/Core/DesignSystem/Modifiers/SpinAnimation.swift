//
//  SpinAnimation.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

// MARK: - Spin Animation Modifier
struct SpinAnimation: ViewModifier {
    @State private var isSpinning = false

    let duration: Double
    let clockwise: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isSpinning ? (clockwise ? 360 : -360) : 0))
            .animation(
                .linear(duration: duration)
                .repeatForever(autoreverses: false),
                value: isSpinning
            )
            .onAppear {
                isSpinning = true
            }
    }
}

// MARK: - View Extension
extension View {
    /// Adds a continuous spinning/rotation animation
    /// - Parameters:
    ///   - duration: Duration for one full rotation (default: 8s)
    ///   - clockwise: Direction of rotation (default: true)
    func spinning(duration: Double = 8.0, clockwise: Bool = true) -> some View {
        modifier(SpinAnimation(duration: duration, clockwise: clockwise))
    }
}
