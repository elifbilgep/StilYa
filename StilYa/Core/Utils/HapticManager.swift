//
//  HapticManager.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 23/12/2024.
//

import UIKit
import SwiftUI

// MARK: - Haptic Feedback Manager

final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    /// Light impact (button taps, small interactions)
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact (swipe actions, card reveals)
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact (major actions, confirmations)
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success feedback (save completed, upload successful)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning feedback (limit reached, caution needed)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error feedback (network error, operation failed)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection changed (picker, segmented control)
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Add haptic feedback to button taps
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
        )
    }

    /// Add success haptic to actions
    func successHaptic() -> some View {
        self.onAppear {
            HapticManager.shared.success()
        }
    }

    /// Add error haptic to actions
    func errorHaptic() -> some View {
        self.onAppear {
            HapticManager.shared.error()
        }
    }
}

// MARK: - Usage Examples
/*
 // In your views:

 // Button tap
 Button("Save") {
     HapticManager.shared.light()
     saveAction()
 }

 // Success action
 if uploadSuccessful {
     HapticManager.shared.success()
 }

 // Error
 if let error = error {
     HapticManager.shared.error()
 }

 // Card swipe
 .gesture(
     DragGesture()
         .onEnded { _ in
             HapticManager.shared.medium()
         }
 )

 // Picker selection
 Picker("Category", selection: $category) {
     // ...
 }
 .onChange(of: category) { _ in
     HapticManager.shared.selectionChanged()
 }
 */
