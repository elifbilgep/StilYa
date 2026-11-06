//
//  AdManager.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 14.03.2026.
//
//  ⚠️ REKLAM SİSTEMİ GEÇİCİ OLARAK DEVRE DIŞI — Tüm kod yorum satırına alındı.
//

/*
import UIKit
import GoogleMobileAds
import Combine

@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published private(set) var isInterstitialReady = false

    private var interstitialAd: InterstitialAd?
    private var isConfigured = false

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Lazy configure — called automatically on first ad request
    func ensureConfigured() {
        guard !isConfigured else { return }
        isConfigured = true
        MobileAds.shared.start { _ in
            #if DEBUG
            print("✅ [AdManager] Google Mobile Ads SDK initialized (lazy)")
            #endif
        }
        preloadInterstitial()
    }

    /// Legacy entry point — now just calls ensureConfigured
    func configure() {
        ensureConfigured()
    }

    // MARK: - Should Show Ads

    /// Only free users see ads
    var shouldShowAds: Bool {
        !RevenueCatManager.shared.isProActive
    }

    // MARK: - Interstitial

    func preloadInterstitial() {
        InterstitialAd.load(
            with: AppConstants.interstitialAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    #if DEBUG
                    print("⚠️ [AdManager] Interstitial load failed: \(error.localizedDescription)")
                    #endif
                    self?.isInterstitialReady = false
                    return
                }
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                self?.isInterstitialReady = true
                #if DEBUG
                print("✅ [AdManager] Interstitial loaded")
                #endif
            }
        }
    }

    /// Show interstitial ad. Calls completion when ad is dismissed or if ad is unavailable.
    func showInterstitial(from viewController: UIViewController? = nil, completion: @escaping () -> Void) {
        ensureConfigured()
        guard shouldShowAds, let ad = interstitialAd else {
            completion()
            return
        }

        let vc = viewController ?? Self.topViewController()
        guard let vc else {
            completion()
            return
        }

        interstitialDismissCompletion = completion
        ad.present(from: vc)
    }

    private var interstitialDismissCompletion: (() -> Void)?

    // MARK: - Helpers

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return findTopVC(from: rootVC)
    }

    private static func findTopVC(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return findTopVC(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return findTopVC(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTopVC(from: selected)
        }
        return vc
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            #if DEBUG
            print("✅ [AdManager] Interstitial dismissed")
            #endif
            interstitialAd = nil
            isInterstitialReady = false
            interstitialDismissCompletion?()
            interstitialDismissCompletion = nil
            preloadInterstitial()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            #if DEBUG
            print("⚠️ [AdManager] Interstitial failed to present: \(error.localizedDescription)")
            #endif
            interstitialAd = nil
            isInterstitialReady = false
            interstitialDismissCompletion?()
            interstitialDismissCompletion = nil
            preloadInterstitial()
        }
    }
}
*/
