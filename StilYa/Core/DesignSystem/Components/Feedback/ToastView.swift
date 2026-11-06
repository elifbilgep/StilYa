//
//  ToastView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 23/12/2024.
//

import SwiftUI

// MARK: - Toast Model

struct Toast: Equatable {
    enum ToastType {
        case success
        case error
        case info
        case warning
    }

    let type: ToastType
    let message: String
    var duration: TimeInterval = 3.0

    var icon: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch type {
        case .success: return Color.success
        case .error: return Color.error
        case .info: return Color.accent
        case .warning: return Color.orange
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: toast.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(toast.color)

            Text(toast.message)
                .font(STFont.bodyMedium)
                .foregroundColor(Color.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMD)
                .fill(Color.bgPrimary)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            // Add haptic feedback
                            switch toast.type {
                            case .success:
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            case .error:
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                            case .info, .warning:
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }

                            // Auto-dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    self.toast = nil
                                }
                            }
                        }
                        .padding(.top, 60) // Below safe area
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toast != nil)
    }
}

// MARK: - View Extension

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }

    /// Show a toast message
    func showToast(_ toast: Toast?) {
        // This is a helper - actual state management should be in the view
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ToastView(toast: Toast(type: .success, message: L10n.previewLookSaved))
        ToastView(toast: Toast(type: .error, message: L10n.previewNetworkError))
        ToastView(toast: Toast(type: .info, message: L10n.previewTriesUsed))
        ToastView(toast: Toast(type: .warning, message: L10n.previewDailyLimitReached))
    }
    .padding(.vertical, 40)
    .background(Color.bgSecondary)
}
