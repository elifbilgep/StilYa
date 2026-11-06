//
//  AnalyticsService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 20.02.2026.
//  Firebase Analytics — Tüm uygulama event'leri merkezi olarak loglanır
//

import Foundation
import FirebaseAnalytics

// MARK: - Analytics Event Names

enum AnalyticsEvent: String {
    // Auth
    case signUp = "sign_up"
    case signIn = "sign_in"
    case signOut = "sign_out"

    // Onboarding
    case onboardingComplete = "onboarding_complete"

    // Try-On
    case tryOnStarted = "try_on_started"
    case tryOnCompleted = "try_on_completed"
    case tryOnFailed = "try_on_failed"

    // Combo
    case comboStarted = "combo_started"
    case comboCompleted = "combo_completed"
    case comboFailed = "combo_failed"

    // Actions
    case lookSaved = "look_saved"
    case savedToGallery = "saved_to_gallery"
    case shared = "shared"
    case addedToCart = "added_to_cart"
    case refineUsed = "refine_used"

    // Credits
    case creditDeducted = "credit_deducted"
    case creditPurchased = "credit_purchased"

    // Subscription
    case proSubscribed = "pro_subscribed"
    case proCancelled = "pro_cancelled"

    // Discover
    case discoverViewed = "discover_viewed"
    case discoverBasketTapped = "discover_basket_tapped"
}

// MARK: - Analytics Parameter Keys

enum AnalyticsParam: String {
    case method              // auth method: email, apple, google
    case garmentType = "garment_type"
    case garmentCount = "garment_count"
    case accessoryCount = "accessory_count"
    case isCombo = "is_combo"
    case creditAmount = "credit_amount"
    case creditBalance = "credit_balance"
    case plan                // weekly, monthly
    case packId = "pack_id"
    case duration            // processing time in seconds
    case source              // tryon, combo
    case hasBrand = "has_brand"
    case hasLink = "has_link"
}

// MARK: - Analytics Service

final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    // MARK: - Generic Log

    func log(_ event: AnalyticsEvent, params: [String: Any]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: params)

        #if DEBUG
        let paramStr = params?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") ?? "none"
        print("📊 [Analytics] \(event.rawValue) — \(paramStr)")
        #endif
    }

    // MARK: - Auth Events

    func logSignUp(method: String) {
        log(.signUp, params: [
            AnalyticsParam.method.rawValue: method
        ])
        Analytics.setUserProperty(method, forName: "auth_method")
    }

    func logSignIn(method: String) {
        log(.signIn, params: [
            AnalyticsParam.method.rawValue: method
        ])
    }

    func logSignOut() {
        log(.signOut)
    }

    // MARK: - Onboarding

    func logOnboardingComplete() {
        log(.onboardingComplete)
    }

    // MARK: - Try-On Events

    func logTryOnStarted(garmentType: String) {
        log(.tryOnStarted, params: [
            AnalyticsParam.garmentType.rawValue: garmentType
        ])
    }

    func logTryOnCompleted(garmentType: String, duration: TimeInterval) {
        log(.tryOnCompleted, params: [
            AnalyticsParam.garmentType.rawValue: garmentType,
            AnalyticsParam.duration.rawValue: Int(duration)
        ])
    }

    func logTryOnFailed(garmentType: String, error: String) {
        log(.tryOnFailed, params: [
            AnalyticsParam.garmentType.rawValue: garmentType,
            "error": String(error.prefix(100))
        ])
    }

    // MARK: - Combo Events

    func logComboStarted(garmentCount: Int, accessoryCount: Int) {
        log(.comboStarted, params: [
            AnalyticsParam.garmentCount.rawValue: garmentCount,
            AnalyticsParam.accessoryCount.rawValue: accessoryCount
        ])
    }

    func logComboCompleted(garmentCount: Int, accessoryCount: Int, duration: TimeInterval) {
        log(.comboCompleted, params: [
            AnalyticsParam.garmentCount.rawValue: garmentCount,
            AnalyticsParam.accessoryCount.rawValue: accessoryCount,
            AnalyticsParam.duration.rawValue: Int(duration)
        ])
    }

    func logComboFailed(error: String) {
        log(.comboFailed, params: [
            "error": String(error.prefix(100))
        ])
    }

    // MARK: - Action Events

    func logLookSaved(isCombo: Bool) {
        log(.lookSaved, params: [
            AnalyticsParam.isCombo.rawValue: isCombo
        ])
    }

    func logSavedToGallery(source: String) {
        log(.savedToGallery, params: [
            AnalyticsParam.source.rawValue: source
        ])
    }

    func logShared(source: String) {
        log(.shared, params: [
            AnalyticsParam.source.rawValue: source
        ])
    }

    func logAddedToCart(garmentType: String, hasBrand: Bool, hasLink: Bool) {
        log(.addedToCart, params: [
            AnalyticsParam.garmentType.rawValue: garmentType,
            AnalyticsParam.hasBrand.rawValue: hasBrand,
            AnalyticsParam.hasLink.rawValue: hasLink
        ])
    }

    func logRefineUsed(source: String) {
        log(.refineUsed, params: [
            AnalyticsParam.source.rawValue: source
        ])
    }

    // MARK: - Credit Events

    func logCreditDeducted(amount: Int, source: String) {
        log(.creditDeducted, params: [
            AnalyticsParam.creditAmount.rawValue: amount,
            AnalyticsParam.source.rawValue: source
        ])
    }

    func logCreditPurchased(packId: String, credits: Int) {
        log(.creditPurchased, params: [
            AnalyticsParam.packId.rawValue: packId,
            AnalyticsParam.creditAmount.rawValue: credits
        ])
    }

    // MARK: - Subscription Events

    func logProSubscribed(plan: String) {
        log(.proSubscribed, params: [
            AnalyticsParam.plan.rawValue: plan
        ])
        Analytics.setUserProperty("true", forName: "is_pro")
        Analytics.setUserProperty(plan, forName: "pro_plan")
    }

    func logProCancelled() {
        log(.proCancelled)
        Analytics.setUserProperty("false", forName: "is_pro")
        Analytics.setUserProperty(nil, forName: "pro_plan")
    }

    // MARK: - Discover Events

    func logDiscoverViewed() {
        log(.discoverViewed)
    }

    func logDiscoverBasketTapped() {
        log(.discoverBasketTapped)
    }

    // MARK: - User Properties

    func setUserId(_ userId: String) {
        Analytics.setUserID(userId)
    }

    func clearUserId() {
        Analytics.setUserID(nil)
    }
}
