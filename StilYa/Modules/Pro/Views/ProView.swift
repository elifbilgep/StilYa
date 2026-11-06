//
//  ProView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//  Updated: 2026-02-15 - RevenueCat purchase integration with custom UI
//

import SwiftUI
import RevenueCat

struct ProView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @State private var selectedPlan: ProPlan = .monthly
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showAccountLinking = false

    var onPurchaseSuccess: (() -> Void)?

    enum ProPlan {
        case weekly, monthly
    }

    /// RevenueCat paketleri yüklendi mi?
    private var hasSubscriptionPackages: Bool {
        revenueCatManager.weeklyPackage != nil || revenueCatManager.monthlyPackage != nil
    }

    /// Monthly plan için weekly'ye kıyasla tasarruf yüzdesi (ör. 23)
    /// Formül: 1 - (monthly / (weekly × 4.33))
    private var monthlySavingsPercent: Int? {
        guard
            let weekly = revenueCatManager.weeklyPackage?.storeProduct.price as NSDecimalNumber?,
            let monthly = revenueCatManager.monthlyPackage?.storeProduct.price as NSDecimalNumber?,
            weekly.doubleValue > 0
        else { return nil }
        let weeklyEquivalent = weekly.doubleValue * 4.33
        guard weeklyEquivalent > 0 else { return nil }
        let savings = (1.0 - (monthly.doubleValue / weeklyEquivalent)) * 100.0
        guard savings > 0 else { return nil }
        return Int(savings.rounded())
    }

    var body: some View {
        if !hasSubscriptionPackages {
            // RevenueCat paketleri henüz yüklenmedi — bekle
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.accent)
                    Text("Loading...")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.textSecondary)
                }
            }
            .task {
                await revenueCatManager.fetchOfferings()
                // 5 saniye sonra hala yoksa kapat
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !hasSubscriptionPackages {
                    dismiss()
                }
            }
        } else {
        ZStack {
            // Pro gradient background
            LinearGradient(
                colors: [Color(hex: "#F5EFE0"), Color.bgPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 44)

                        // Pro Title
                        VStack(spacing: 12) {
                            Text(L10n.proTitle)
                                .font(STFont.displayXLarge)
                                .foregroundColor(.textPrimary)

                            Text(L10n.proSubtitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        Spacer().frame(height: 40)

                        // Features List
                        VStack(spacing: 14) {
                            ProFeatureRow(
                                icon: "sparkles",
                                title: L10n.proWeeklyCredits,
                                description: L10n.proWeeklyCreditsDesc(AppConstants.proWeeklyCredits)
                            )

                            ProFeatureRow(
                                icon: "square.stack.3d.up.fill",
                                title: L10n.proComboFeature,
                                description: L10n.proComboFeatureDesc
                            )

                            ProFeatureRow(
                                icon: "cabinet.fill",
                                title: L10n.proClosetFeature,
                                description: L10n.proClosetFeatureDesc
                            )

                            ProFeatureRow(
                                icon: "bolt.fill",
                                title: L10n.proPriorityProcessing,
                                description: L10n.proPriorityProcessingDesc
                            )

                            ProFeatureRow(
                                icon: "person.crop.rectangle.fill",
                                title: L10n.proAIModelPhoto,
                                description: L10n.proAIModelPhotoDesc
                            )

                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        Spacer().frame(height: 32)

                        // Plan Selection — weekly + monthly
                        // Her iki planda da haftalık 50 kredi verilir (worker side weekly reset)
                        HStack(spacing: 12) {
                            proPlanCard(
                                plan: .weekly,
                                title: L10n.proWeekly,
                                price: revenueCatManager.weeklyPackage?.storeProduct.localizedPriceString ?? AppConstants.proWeeklyPriceTR,
                                period: L10n.proPerWeek,
                                badge: nil,
                                detail: L10n.proWeeklyCreditsDesc(AppConstants.proWeeklyCredits)
                            )

                            proPlanCard(
                                plan: .monthly,
                                title: L10n.proMonthly,
                                price: revenueCatManager.monthlyPackage?.storeProduct.localizedPriceString ?? AppConstants.proMonthlyPriceTR,
                                period: L10n.proPerMonth,
                                badge: L10n.proBestValue,
                                detail: L10n.proWeeklyCreditsDesc(AppConstants.proWeeklyCredits),
                                savingsPercent: monthlySavingsPercent
                            )
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // Error message
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.error)
                                .padding(.top, 8)
                                .padding(.horizontal, Spacing.screenHorizontal)
                        }

                        Spacer().frame(height: 16)
                    }
                }

                // Sticky bottom: Subscribe button + Terms
                VStack(spacing: 12) {
                    // Subscribe button
                    Button(action: {
                        if let authVM = container.authViewModel, !authVM.requireAccountLinking(context: .buyPro) {
                            showAccountLinking = true
                            return
                        }
                        Task { await purchaseSelectedPlan() }
                    }) {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "crown.fill")
                                Text(L10n.proUpgrade)
                            }
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.proGold, Color(hex: "#D4B06A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isPurchasing)

                    // Restore purchases button
                    Button(action: {
                        Task { await restorePurchases() }
                    }) {
                        Text(L10n.proRestore)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }

                    // Terms (seçilen plana göre)
                    Text(selectedPlan == .weekly ? L10n.proWeeklyAutoRenew : L10n.proMonthlyAutoRenew)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    // Terms of Use & Privacy Policy links
                    HStack(spacing: 4) {
                        Link(L10n.profileTermsOfUse, destination: LegalURLs.termsOfUse)
                        Text("·")
                            .foregroundColor(.textSecondary.opacity(0.5))
                        Link(L10n.profilePrivacyPolicy, destination: LegalURLs.privacyPolicy)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary.opacity(0.7))
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color.bgPrimary)
            }
        }
        .sheet(isPresented: $showAccountLinking) {
            if let authVM = container.authViewModel {
                AccountLinkingSheet(authViewModel: authVM)
                    .preferredColorScheme(.light)
            }
        }
        .task {
            // Lazy fetch offerings when ProView is opened
            if revenueCatManager.offerings == nil {
                await revenueCatManager.fetchOfferings()
            }
        }
        } // else hasSubscriptionPackages
    }

    private func purchaseSelectedPlan() async {
        let package: Package? = selectedPlan == .weekly
            ? revenueCatManager.weeklyPackage
            : revenueCatManager.monthlyPackage

        guard let package else {
            errorMessage = L10n.proPurchaseError
            return
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let customerInfo = try await revenueCatManager.purchase(package: package)
            let isPro = customerInfo.entitlements[AppConstants.proEntitlementID]?.isActive == true
            if isPro {
                await syncProStatusToFirestore(isPro: true, customerInfo: customerInfo)
                if let onPurchaseSuccess {
                    onPurchaseSuccess()
                } else {
                    dismiss()
                }
            }
        } catch {
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                // User cancelled, no error message needed
            } else {
                errorMessage = L10n.proPurchaseError
            }
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil

        do {
            let customerInfo = try await revenueCatManager.restorePurchases()
            let isPro = customerInfo.entitlements[AppConstants.proEntitlementID]?.isActive == true
            if isPro {
                await syncProStatusToFirestore(isPro: true, customerInfo: customerInfo)
                if let onPurchaseSuccess {
                    onPurchaseSuccess()
                } else {
                    dismiss()
                }
            } else {
                errorMessage = L10n.proRestoreNoPurchases
            }
        } catch {
            errorMessage = L10n.proRestoreError
        }

        isPurchasing = false
    }

    private func syncProStatusToFirestore(isPro: Bool, customerInfo: CustomerInfo) async {
        // Sync Pro status via Worker (server-side Firestore update) with retry
        var lastError: Error?
        for attempt in 1...3 {
            do {
                try await WorkerAPIService.shared.syncPro()
                #if DEBUG
                print("✅ [ProView] Pro status synced via Worker (attempt \(attempt))")
                #endif
                return
            } catch {
                lastError = error
                #if DEBUG
                print("⚠️ [ProView] Worker syncPro attempt \(attempt) failed: \(error.localizedDescription)")
                #endif
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        #if DEBUG
        print("❌ [ProView] Worker syncPro failed after 3 attempts: \(lastError?.localizedDescription ?? "unknown")")
        #endif
    }
}

// MARK: - Pro Plan Card
extension ProView {
    func proPlanCard(
        plan: ProPlan,
        title: String,
        price: String,
        period: String,
        badge: String?,
        detail: String,
        savingsPercent: Int? = nil
    ) -> some View {
        Button(action: { selectedPlan = plan }) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.proGold)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 20)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text(period)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                if let savingsPercent = savingsPercent {
                    Text("Save \(savingsPercent)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.proGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.proGold.opacity(0.15))
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedPlan == plan ? Color.proGold.opacity(0.08) : Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedPlan == plan ? Color.proGold : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pro Feature Row
private struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.proGold.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(.proGold)
            }

            // Text
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.proGold)
        }
    }
}

#Preview {
    ProView()
}
