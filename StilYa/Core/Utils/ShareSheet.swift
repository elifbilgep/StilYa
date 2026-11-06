//
//  ShareSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 23/12/2024.
//

import SwiftUI
import UIKit

// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View Extension for Easy Sharing

extension View {
    /// Present a share sheet with the given items
    func shareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        sheet(isPresented: isPresented) {
            ShareSheet(items: items)
        }
    }
}

// MARK: - Shareable Content Builders

struct ShareableContent {
    /// Share a try-on result image with text
    static func tryOnResult(image: UIImage) -> [Any] {
        let text = L10n.shareTryOnResult
        return [image, text]
    }

    /// Share just the image
    static func image(_ image: UIImage) -> [Any] {
        return [image]
    }

    /// Share app link
    static func appLink() -> [Any] {
        let text = L10n.shareAppLink
        return [text]
    }

    /// Share referral code
    static func referralCode(_ code: String) -> [Any] {
        let text = L10n.shareReferralCode(code)
        return [text]
    }

    /// Share a look with custom text
    static func look(image: UIImage, customText: String? = nil) -> [Any] {
        let defaultText = L10n.shareLookResult
        return [image, customText ?? defaultText]
    }
}

// MARK: - Helper for getting root view controller

extension UIApplication {
    var currentKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    var rootViewController: UIViewController? {
        currentKeyWindow?.rootViewController
    }
}

// MARK: - Alternative: Present share sheet programmatically

struct ShareHelper {
    /// Present share sheet programmatically (use when not in SwiftUI context)
    static func share(items: [Any], from viewController: UIViewController? = nil) {
        let vc = viewController ?? UIApplication.shared.rootViewController

        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // For iPad: configure popover
        if let popoverController = activityVC.popoverPresentationController,
           let sourceView = vc?.view {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        vc?.present(activityVC, animated: true)
    }
}
