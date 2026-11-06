//
//  StilYaApp.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn
import RevenueCat
import GoogleMobileAds

// MARK: - Firebase Configuration Helper
extension FirebaseApp {
    static var isConfigured = false

    static func configureOnce() {
        guard !isConfigured else { return }
        // App Check MUST be set BEFORE FirebaseApp.configure()
        AppCheck.setAppCheckProviderFactory(StilYaAppCheckProviderFactory())
        FirebaseApp.configure()
        isConfigured = true
        #if DEBUG
        print("✅ Firebase configured successfully (App Check enabled)")
        #endif
    }
}

// MARK: - Firebase App Delegate Adapter
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configureOnce()

        // Home screen quick actions (long-press menu)
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.stilya.feedback",
                localizedTitle: NSLocalizedString("Feedback", comment: ""),
                localizedSubtitle: NSLocalizedString("Help us improve", comment: ""),
                icon: UIApplicationShortcutIcon(systemImageName: "envelope"),
                userInfo: nil
            )
        ]

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if shortcutItem.type == "com.stilya.feedback" {
            openFeedbackMail()
        }
        completionHandler(true)
    }

    private func openFeedbackMail() {
        let email = "feedback@stilya.app"
        let subject = "StilYa Feedback"
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

@main
struct StilYaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var container = AppContainer()
    @StateObject private var router = RouterManager()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared

    /// Prevents duplicate syncPro calls during initial launch
    @MainActor static var initialSyncDone = false

    init() {
        FirebaseApp.configureOnce()
        RevenueCatManager.shared.configure(apiKey: AppConstants.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                SplashView()
                    .navigationDestination(for: Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .background(Color.bgPrimary)
            .navigationBarHidden(true)
            .tint(.accent)
            #if DEBUG
            .shakeToDebug()
            #endif
            .onOpenURL { url in
                // Deep link handling: stilya://tryon
                if url.scheme == "stilya" {
                    handleDeepLink(url)
                    return
                }
                // Google Sign-In
                GIDSignIn.sharedInstance.handle(url)
            }
            .onAppear {
                setupRevenueCatCallback()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    container.cleanupOnBackground()
                }
            }
        }
        .environmentObject(container)
        .environmentObject(router)
        .environmentObject(localizationManager)
        .environmentObject(revenueCatManager)
    }

    private func setupRevenueCatCallback() {
        RevenueCatManager.shared.onProStatusChanged = { isPro, plan, customerInfo in
            Task {
                // Skip if SplashView already synced during initial launch
                guard StilYaApp.initialSyncDone else {
                    #if DEBUG
                    print("ℹ️ [App] Pro status callback skipped (initial sync not yet done by SplashView)")
                    #endif
                    return
                }

                #if DEBUG
                print("🔄 [App] Pro status callback: isPro=\(isPro), plan=\(plan ?? "nil")")
                #endif

                // Sync Pro status via Worker (server-side Firestore update) with retry
                for attempt in 1...3 {
                    do {
                        try await WorkerAPIService.shared.syncPro()
                        #if DEBUG
                        print("✅ [App] Worker syncPro succeeded (attempt \(attempt))")
                        #endif
                        return
                    } catch {
                        #if DEBUG
                        print("⚠️ [App] Worker syncPro attempt \(attempt) failed: \(error.localizedDescription)")
                        #endif
                        if attempt < 3 {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                        }
                    }
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }
        switch host {
        case "tryon":
            // stilya://tryon → Kıyafet Dene
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                router.push(.dressUp)
            }
        case "closet":
            // stilya://closet → Dijital Dolap
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .openClosetDeepLink, object: nil)
            }
        default:
            break
        }
    }

    @ViewBuilder
    private func destinationView(for destination: Destination) -> some View {
        switch destination {
        case .welcome:
            WelcomeView()
        case .signUp:
            SignUpView()
        case .signIn:
            SignInView()
        case .onboarding:
            OnboardingView()
        case .home:
            MainTabView()
        case .looks:
            LooksView()
        case .trendMagazine:
            TrendCollectionsView()
        case .dressUp:
            DressUpFlowView()
                .navigationBarBackButtonHidden(true)
        case .profile:
            ProfileView()
        }
    }
}
