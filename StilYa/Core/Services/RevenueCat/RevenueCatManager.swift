//
//  RevenueCatManager.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 15.02.2026.
//

import Foundation
import RevenueCat
import Combine

@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    // MARK: - Published State
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isProActive: Bool = false
    @Published private(set) var isLoading: Bool = false

    // MARK: - Entitlement IDs
    static let proEntitlementID = "StilYa Pro"

    // MARK: - Callbacks
    var onProStatusChanged: ((Bool, String?, CustomerInfo) -> Void)?

    // MARK: - Init
    private override init() {
        super.init()
    }

    #if DEBUG
    /// Debug-only: force Pro status for testing
    func debugSetPro(_ value: Bool) {
        isProActive = value
    }
    #endif

    // MARK: - Configuration

    /// Configure RevenueCat SDK - call once at app launch
    func configure(apiKey: String, appUserID: String? = nil) {
        // Open-source builds may run without RevenueCat — purchases are then disabled.
        guard !apiKey.isEmpty else {
            print("⚠️ [RevenueCat] REVENUECAT_API_KEY not set — purchases disabled")
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        if let appUserID {
            Purchases.configure(withAPIKey: apiKey, appUserID: appUserID)
        } else {
            Purchases.configure(withAPIKey: apiKey)
        }

        // Set delegate for real-time updates
        Purchases.shared.delegate = self

        #if DEBUG
        print("✅ [RevenueCat] Configured (offerings deferred until needed)")
        #endif

        // Only fetch customer info at launch (lightweight)
        // Offerings are fetched lazily when ProView or purchase UI is shown
        Task {
            await fetchCustomerInfo()
        }
    }

    // MARK: - Login / Logout

    /// Login with Firebase user ID for cross-device entitlement sync
    func login(appUserID: String) async {
        guard Purchases.isConfigured else { return }
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(appUserID)
            self.customerInfo = customerInfo
            self.isProActive = checkPro(customerInfo)
            #if DEBUG
            print("✅ [RevenueCat] Logged in as: \(appUserID), isPro: \(isProActive)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [RevenueCat] Login failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Logout - resets to anonymous user
    func logout() async {
        guard Purchases.isConfigured else { return }
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            self.isProActive = false
            #if DEBUG
            print("✅ [RevenueCat] Logged out")
            #endif
        } catch {
            #if DEBUG
            print("❌ [RevenueCat] Logout failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Customer Info

    /// Fetch latest customer info
    func fetchCustomerInfo() async {
        guard Purchases.isConfigured else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            self.isProActive = checkPro(customerInfo)
        } catch {
            #if DEBUG
            print("❌ [RevenueCat] Failed to fetch customer info: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Offerings

    /// Fetch available offerings/products
    func fetchOfferings() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            #if DEBUG
            print("✅ [RevenueCat] Offerings fetched: \(offerings.current?.availablePackages.count ?? 0) packages")
            for pkg in offerings.current?.availablePackages ?? [] {
                print("   📦 \(pkg.identifier): \(pkg.storeProduct.localizedPriceString) - \(pkg.storeProduct.localizedTitle)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ [RevenueCat] Failed to fetch offerings: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Purchases

    /// Purchase a package (subscription or consumable)
    /// - Throws: `CancellationError` if user cancelled, or RevenueCat errors
    func purchase(package: Package) async throws -> CustomerInfo {
        guard Purchases.isConfigured else { throw RevenueCatNotConfiguredError() }
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)

        // Kullanıcı iptal ettiyse kredi eklenmemeli
        guard !result.userCancelled else {
            #if DEBUG
            print("⚠️ [RevenueCat] Purchase cancelled by user")
            #endif
            throw CancellationError()
        }

        let customerInfo = result.customerInfo
        self.customerInfo = customerInfo
        self.isProActive = checkPro(customerInfo)

        #if DEBUG
        print("✅ [RevenueCat] Purchase successful! product: \(package.storeProduct.productIdentifier), isPro: \(isProActive)")
        #endif

        if isProActive, let plan = activeSubscriptionPlan {
            AnalyticsService.shared.logProSubscribed(plan: plan)
        }

        return customerInfo
    }

    /// Restore purchases
    func restorePurchases() async throws -> CustomerInfo {
        guard Purchases.isConfigured else { throw RevenueCatNotConfiguredError() }
        isLoading = true
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        self.customerInfo = customerInfo
        self.isProActive = checkPro(customerInfo)

        #if DEBUG
        print("✅ [RevenueCat] Purchases restored! isPro: \(isProActive)")
        #endif

        return customerInfo
    }

    // MARK: - Helpers

    /// Get the current offering's packages
    var currentPackages: [Package] {
        offerings?.current?.availablePackages ?? []
    }

    /// Get weekly subscription package
    var weeklyPackage: Package? {
        offerings?.current?.weekly
    }

    /// Get monthly subscription package
    var monthlyPackage: Package? {
        offerings?.current?.monthly
    }

    /// Check if a specific entitlement is active
    func isEntitlementActive(_ entitlementID: String) -> Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }

    /// Check Pro status — entitlement active = Pro
    private func checkPro(_ customerInfo: CustomerInfo) -> Bool {
        let isActive = customerInfo.entitlements[Self.proEntitlementID]?.isActive == true
        #if DEBUG
        print("🔍 [RevenueCat] checkPro — '\(Self.proEntitlementID)' isActive: \(isActive)")
        #endif
        return isActive
    }

    /// Determine active subscription plan type from product identifier
    var activeSubscriptionPlan: String? {
        guard let entitlement = customerInfo?.entitlements[Self.proEntitlementID],
              entitlement.isActive else { return nil }
        let productID = entitlement.productIdentifier
        if productID == AppConstants.proWeeklyID { return "weekly" }
        if productID == AppConstants.proMonthlyID { return "monthly" }
        return "weekly" // Default fallback
    }
}

// MARK: - PurchasesDelegate

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            let wasPro = self.isProActive
            self.customerInfo = customerInfo

            self.isProActive = checkPro(customerInfo)

            #if DEBUG
            print("🔄 [RevenueCat] Customer info updated, isPro: \(self.isProActive)")
            #endif

            // Notify on status change & log analytics
            if self.isProActive != wasPro {
                if !self.isProActive && wasPro {
                    AnalyticsService.shared.logProCancelled()
                } else if self.isProActive, let plan = self.activeSubscriptionPlan {
                    AnalyticsService.shared.logProSubscribed(plan: plan)
                }
                self.onProStatusChanged?(self.isProActive, self.activeSubscriptionPlan, customerInfo)
                NotificationCenter.default.post(name: .proStatusDidChange, object: nil)
            }
        }
    }
}


/// Thrown when purchase APIs are used without a RevenueCat API key configured.
struct RevenueCatNotConfiguredError: LocalizedError {
    var errorDescription: String? { "In-app purchases are not configured in this build." }
}
