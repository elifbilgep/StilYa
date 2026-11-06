//
//  SplashView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

// MARK: - Four-Pointed Star Shape
private struct FourPointedStarShape: Shape {
    var innerRatio: CGFloat = 0.38

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let outerX = rect.width / 2
        let outerY = rect.height / 2
        let innerX = outerX * innerRatio
        let innerY = outerY * innerRatio

        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - outerY))
        path.addLine(to: CGPoint(x: cx + innerX, y: cy - innerY))
        path.addLine(to: CGPoint(x: cx + outerX, y: cy))
        path.addLine(to: CGPoint(x: cx + innerX, y: cy + innerY))
        path.addLine(to: CGPoint(x: cx, y: cy + outerY))
        path.addLine(to: CGPoint(x: cx - innerX, y: cy + innerY))
        path.addLine(to: CGPoint(x: cx - outerX, y: cy))
        path.addLine(to: CGPoint(x: cx - innerX, y: cy - innerY))
        path.closeSubpath()
        return path
    }
}

struct SplashView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager

    @State private var revealSize: CGFloat = 0
    @State private var showStar = false
    @State private var showMaintenance = false
    @State private var maintenanceMessage: String?

    var body: some View {
        ZStack {
            Color(hex: "#1A1A1A").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                STLogoView(
                    size: 100,
                    iconColor: .white,
                    backgroundColor: .white.opacity(0.1),
                    animateSparkle: true
                )

                Spacer().frame(height: 40)

                VStack(spacing: Spacing.md) {
                    Text("STILYA")
                        .font(STFont.displayLarge)
                        .tracking(2)
                        .foregroundColor(.white)

                    Text(L10n.splashSubtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }

                Spacer()
            }

            // Maintenance overlay
            if showMaintenance {
                Color(hex: "#1A1A1A").ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    STLogoView(
                        size: 80,
                        iconColor: .white,
                        backgroundColor: .white.opacity(0.1),
                        animateSparkle: false
                    )

                    Text("STILYA")
                        .font(STFont.displayLarge)
                        .tracking(2)
                        .foregroundColor(.white)

                    Spacer().frame(height: 8)

                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.5))

                    Text(maintenanceMessage ?? L10n.commonMaintenanceMessage)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)

                    Spacer()
                }
            }

            // Yıldız geçişi — ekranı bgPrimary ile kaplayarak navigasyonu gizler
            if showStar {
                Color.bgPrimary
                    .ignoresSafeArea()
                    .mask(
                        FourPointedStarShape()
                            .frame(width: revealSize, height: revealSize)
                            .blur(radius: 40)
                    )
            }
        }
        .task {
            container.onLogout = {
                router.popToRoot()
                router.push(.welcome)
            }

            // Fetch remote config + RevenueCat offerings + splash delay in parallel
            async let configTask = WorkerAPIService.shared.fetchRemoteConfig()
            async let rcTask: () = RevenueCatManager.shared.fetchOfferings()
            async let delayTask: () = Task.sleep(nanoseconds: 2_000_000_000)
            let config = await configTask
            _ = await rcTask
            _ = try? await delayTask

            // Remote config → update runtime constants
            if let freeCredits = config.freeWeeklyCredits, freeCredits >= 0 {
                AppConstants.freeWeeklyCredits = freeCredits
            }
            if let trial = config.trialCredits, trial >= 0 {
                AppConstants.trialCredits = trial
            }
            if let proCredits = config.proWeeklyCredits, proCredits > 0 {
                AppConstants.proWeeklyCredits = proCredits
                AppConstants.proMonthlyCredits = proCredits
            }

            // App kill switch
            if config.appEnabled == false {
                maintenanceMessage = config.maintenanceMessage
                showMaintenance = true
                return
            }

            appLog("App launched, checking auth...", category: .auth)
            let destination = await resolveDestination()

            // Yıldız animasyonu başla
            showStar = true
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                revealSize = UIScreen.main.bounds.height * 2.5
            }

            // Yıldız ekranı tamamen kaplayınca navigate et (kullanıcı geçişi görmez)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                router.pushWithoutAnimation(destination)
            }
        }
    }

    // MARK: - Resolve Destination
    private func resolveDestination() async -> Destination {
        if let userId = container.authRepository.getCurrentUserId() {
            container.initializeAuthViewModel()
            container.authViewModel?.currentUserId = userId

            await syncProStatus(userId: userId)

            appLog("User found: \(userId), loading...", category: .auth)
            if let user = try? await container.userRepository.getUser(id: userId) {
                await EncryptionService.migrateKeyToFirestoreIfNeeded(
                    userId: userId,
                    user: user,
                    userRepository: container.userRepository
                )

                if user.hasModelImage {
                    container.initializeLooksViewModel()
                    container.initializeClosetViewModel(userId: userId)
                    return .home
                } else {
                    return .onboarding
                }
            } else {
                return .welcome
            }
        } else {
            // No existing user — show Welcome so user can choose auth method
            return .welcome
        }
    }

    // MARK: - Sync Pro Status
    private func syncProStatus(userId: String) async {
        let rcManager = RevenueCatManager.shared
        await rcManager.login(appUserID: userId)
        await rcManager.fetchCustomerInfo()

        do {
            let result = try await WorkerAPIService.shared.syncPro()
            #if DEBUG
            print("✅ [Splash] Pro status synced via Worker: isPro=\(result.isPro ?? false), credits=\(result.credits ?? 0)")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [Splash] Worker sync failed, continuing: \(error.localizedDescription)")
            print("ℹ️ [Splash] RevenueCat client-side isPro: \(rcManager.isProActive) (will be used as source of truth)")
            #endif
        }

        StilYaApp.initialSyncDone = true
    }
}

#Preview {
    SplashView()
}
