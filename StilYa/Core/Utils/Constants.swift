//
//  Constants.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation

enum AppConstants {
    // MARK: - App Info
    static let appName = "STILYA"
    static let tagline = "Satın almadan önce dene"
    static let onboardingTotalSteps = 10

    // MARK: - Credit System
    // Pay-to-use: haftalık ücretsiz kredi yenilenmez (0). Yeni hesap açılışında
    // bir kez `trialCredits` verilir. İkisi de remote config'den güncellenir.
    static var freeWeeklyCredits = 0          // Tekrarlayan haftalık ücretsiz kredi — pay-to-use'da 0
    static var trialCredits = 1               // Hesap açılışında tek seferlik deneme kredisi
    // firstPurchaseBonusCredits kaldırıldı — referral bug'ı ve gereksiz karmaşıklık nedeniyle
    static let singleTryOnCost = 1            // Tek parça = 1 kredi
    static let comboBaseCost = 1              // Kombin = tek API call, aynı maliyet

    // MARK: - Subscriptions
    static let proWeeklyID = "weekly"
    static let proMonthlyID = "monthly"
    static var proWeeklyCredits = 50           // 50 deneme/hafta — remote config'den güncellenir
    static var proMonthlyCredits = 50          // 50 deneme/hafta — remote config'den güncellenir

    /// Whitelist: subscription product IDs (Pro grants)
    static let subscriptionProductIDs: Set<String> = [proWeeklyID, proMonthlyID]

    /// Check if a product ID is a subscription (not a consumable credit pack)
    static func isSubscriptionProduct(_ productId: String) -> Bool {
        subscriptionProductIDs.contains(productId)
    }

    // MARK: - Subscription Prices (Fallback — gerçek fiyat RevenueCat'ten gelir)
    static let proWeeklyPriceTR = "₺79.99"
    static let proMonthlyPriceTR = "₺399.99"
    static let proWeeklyPriceUSD = "$2.49"
    static let proMonthlyPriceUSD = "$14.99"

    // MARK: - Referral System
    static let referralBonusCredits = 2
    static let referralCodePrefix = "STILYA"

    // MARK: - Credit Packs (UI display amounts must match worker creditAmount)
    static let creditPack5ID = "com.stilya.credits.5"
    static let creditPack20ID = "com.stilya.credits.20"
    static let creditPack60ID = "com.stilya.credits.60"
    static let creditPack5Amount = 5          // Worker: 5 kredi
    static let creditPack20Amount = 20        // Worker: 20 kredi
    static let creditPack60Amount = 60        // Worker: 60 kredi

    // Display prices (Fallback — gerçek fiyat RevenueCat'ten gelir)
    static let creditPack5PriceTR = "₺69.99"        // Başlangıç
    static let creditPack20PriceTR = "₺299.99"      // Popüler
    static let creditPack60PriceTR = "₺899.99"      // Avantajlı
    static let creditPack5PriceUSD = "$2.49"         // Starter
    static let creditPack20PriceUSD = "$9.99"        // Popular
    static let creditPack60PriceUSD = "$29.99"       // Best Value

    // MARK: - Ads (AdMob) — temporarily disabled (see AdManager.swift).
    // The AdMob app ID is set via ADMOB_APP_ID in Config/Secrets.xcconfig.

    // MARK: - Image Settings
    static let imageCompressionQuality: CGFloat = 0.8
    static let imageMaxSize: CGFloat = 1024

    // MARK: - Try-On Settings
    static let tryOnResolution = CGSize(width: 576, height: 864)
    static let estimatedProcessingTime: TimeInterval = 13.0 // 11-15 seconds avg

    // MARK: - RevenueCat
    static var revenueCatAPIKey: String { Configuration.shared.revenueCatAPIKey }
    static let proEntitlementID = "StilYa Pro"

    // MARK: - API (Cloudflare Worker Proxy)
    // All API keys (FAL_KEY etc.) live in the Cloudflare Worker as secrets.
    // The app only sends a Firebase Auth token to Configuration.apiBaseURL.
}

enum FirestoreCollections {
    static let users = "users"
    static let looks = "looks"
    static let garments = "garments"
    static let referralCodes = "referralCodes"
    static let deviceReferrals = "deviceReferrals"
    static let feedback = "feedback"
}
