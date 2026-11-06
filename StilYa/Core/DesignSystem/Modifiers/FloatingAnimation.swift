//
//  FloatingAnimation.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

// MARK: - Floating Animation Modifier
struct FloatingAnimation: ViewModifier {
    @State private var isFloating = false

    let distance: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -distance : 0)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

// MARK: - View Extension
extension View {
    /// Adds a floating animation (up and down movement)
    /// - Parameters:
    ///   - distance: How far to float (default: 10pt)
    ///   - duration: Animation duration (default: 3s)
    func floating(distance: CGFloat = 10, duration: Double = 3.0) -> some View {
        modifier(FloatingAnimation(distance: distance, duration: duration))
    }
}
