//
//  AuthViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import RevenueCat
import GoogleSignIn

// MARK: - Account Linking Context
enum AccountLinkingContext {
    case saveLook, addToCart, addToCloset, buyPro, generic

    var subtitle: String {
        switch self {
        case .saveLook: return L10n.accountLinkingSubtitleSaveLook
        case .addToCart: return L10n.accountLinkingSubtitleAddToCart
        case .addToCloset: return L10n.accountLinkingSubtitleAddToCloset
        case .buyPro: return L10n.accountLinkingSubtitleBuyPro
        case .generic: return L10n.accountLinkingSubtitleGeneric
        }
    }

    var icon: String {
        switch self {
        case .saveLook: return "heart.fill"
        case .addToCart: return "cart.fill"
        case .addToCloset: return "cabinet.fill"
        case .buyPro: return "crown.fill"
        case .generic: return "person.crop.circle.badge.plus"
        }
    }
}

@Observable
final class AuthViewModel {
    // MARK: - Properties
    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let referralRepository: ReferralRepository

    var currentUserId: String?
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    var isDeviceBlocked = false
    var didDetectCreditAbuse = false

    // MARK: - Anonymous / Account Linking
    var showAccountLinkingSheet = false
    var accountLinkingContext: AccountLinkingContext = .generic
    var isLinking = false
    var linkingProvider: SocialProvider?
    var isCredentialInUseError = false
    var prefillEmail: String?

    var isAnonymous: Bool {
        authRepository.isCurrentUserAnonymous()
    }

    // MARK: - Computed Properties
    var isAuthenticated: Bool {
        currentUserId != nil
    }

    var hasCompletedOnboarding: Bool {
        currentUser?.hasModelImage ?? false
    }

    // MARK: - Initialization
    init(authRepository: AuthRepository, userRepository: UserRepository, referralRepository: ReferralRepository) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.referralRepository = referralRepository
        self.currentUserId = authRepository.getCurrentUserId()
    }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    @MainActor
    func signInWithEmail(email: String, password: String) async {
        #if DEBUG
        print("🔐 [Auth] Starting email sign in for: \(email)")
        #endif
        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authRepository.signInWithEmail(email: email, password: password)
            currentUserId = userId
            appLog("Email sign in successful: \(userId)", category: .auth)
            AnalyticsService.shared.logSignIn(method: "email")
            AnalyticsService.shared.setUserId(userId)
            #if DEBUG
            print("✅ [Auth] Email sign in successful. User ID: \(userId)")
            #endif

            // Sync RevenueCat with Firebase user ID
            await RevenueCatManager.shared.login(appUserID: userId)

            // Load existing user from Firestore
            await loadCurrentUser()

            // Sync encryption key (cross-device support)
            if let user = currentUser {
                await EncryptionService.syncEncryptionKey(userId: userId, user: user, userRepository: userRepository)
            }

        } catch {
            #if DEBUG
            print("❌ [Auth] Email sign in failed: \(error)")
            #endif
            appLog("Email sign in failed: \(error.localizedDescription)", category: .auth)
            errorMessage = error.friendlyAuthMessage
        }

        isLoading = false
    }

    /// Sign up with email and password
    @MainActor
    func signUpWithEmail(email: String, password: String) async {
        #if DEBUG
        print("🔐 [Auth] Starting email sign up for: \(email)")
        #endif
        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authRepository.signUpWithEmail(email: email, password: password)
            currentUserId = userId
            appLog("Email sign up successful: \(userId)", category: .auth)
            AnalyticsService.shared.logSignUp(method: "email")
            AnalyticsService.shared.setUserId(userId)
            #if DEBUG
            print("✅ [Auth] Email sign up successful. User ID: \(userId)")
            #endif

            // Sync RevenueCat with Firebase user ID
            await RevenueCatManager.shared.login(appUserID: userId)

            // Device check — abuse prevention (Keychain + Apple DeviceCheck)
            let fingerprint = KeychainService.getOrCreateDeviceFingerprint()
            let deviceCheck = try await WorkerAPIService.shared.checkDevice(fingerprint: fingerprint)
            if deviceCheck.allowed != true {
                // Blocked — reset auth state so user stays on Welcome
                try? authRepository.signOut()
                await RevenueCatManager.shared.logout()
                currentUserId = nil
                currentUser = nil
                isDeviceBlocked = true
                errorMessage = deviceCheck.error ?? L10n.errorDeviceBlocked
                isLoading = false
                return
            }

            // Create user document in Firestore
            // If device already claimed free credits (reinstall), start with 0
            var newUser = User(id: userId, deviceId: fingerprint)
            if deviceCheck.freeCreditsAlreadyClaimed == true {
                newUser.credits = 0
                didDetectCreditAbuse = true
                #if DEBUG
                print("⚠️ [Auth] Device already claimed free credits — starting with 0")
                #endif
            }
            try await userRepository.createUser(newUser)
            currentUser = newUser
            #if DEBUG
            print("✅ [Auth] User document created in Firestore")
            #endif

            // Sync encryption key (cross-device support)
            await EncryptionService.syncEncryptionKey(userId: userId, user: newUser, userRepository: userRepository)

        } catch {
            #if DEBUG
            print("❌ [Auth] Email sign up failed: \(error)")
            #endif
            errorMessage = error.friendlyAuthMessage
        }

        isLoading = false
    }

    /// Sign in/up with Apple
    @MainActor
    func signInWithApple() async {
        #if DEBUG
        print("🔐 [Auth] Starting Apple sign in...")
        #endif
        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authRepository.signInWithApple()
            currentUserId = userId
            appLog("Apple sign in successful: \(userId)", category: .auth)
            AnalyticsService.shared.setUserId(userId)
            #if DEBUG
            print("✅ [Auth] Apple sign in successful. User ID: \(userId)")
            #endif

            // Sync RevenueCat with Firebase user ID
            await RevenueCatManager.shared.login(appUserID: userId)

            // Get display name from Firebase Auth profile (set during Apple sign-in delegate)
            let firebaseDisplayName = Auth.auth().currentUser?.displayName

            // Try to load existing user, if not exists create new one
            let existingUser = try await userRepository.getUser(id: userId)
            if let user = existingUser {
                currentUser = user
                AnalyticsService.shared.logSignIn(method: "apple")
                #if DEBUG
                print("✅ [Auth] Existing user loaded")
                #endif

                // Ensure deviceId is saved (may be missing from older accounts)
                if user.deviceId == nil || user.deviceId?.isEmpty == true {
                    let deviceId = KeychainService.getOrCreateDeviceFingerprint()
                    try? await userRepository.updateDeviceId(userId: userId, deviceId: deviceId)
                    #if DEBUG
                    print("📱 [Auth] Backfilled missing deviceId for Apple user")
                    #endif
                }

                // Backfill display name if missing in Firestore but available from Firebase Auth
                if (user.displayName == nil || user.displayName?.isEmpty == true),
                   let authName = firebaseDisplayName, !authName.isEmpty {
                    try? await userRepository.updateProfileInfo(userId: userId, displayName: authName, gender: user.gender ?? "", height: user.height, bodyType: user.bodyType, closetColor: user.closetColor)
                    currentUser?.displayName = authName
                    #if DEBUG
                    print("📝 [Auth] Backfilled missing displayName for Apple user: \(authName)")
                    #endif
                }
            } else {
                // Device check — abuse prevention (Keychain + Apple DeviceCheck)
                let fingerprint = KeychainService.getOrCreateDeviceFingerprint()
                let deviceCheck = try await WorkerAPIService.shared.checkDevice(fingerprint: fingerprint)
                if deviceCheck.allowed != true {
                    try? authRepository.signOut()
                    await RevenueCatManager.shared.logout()
                    currentUserId = nil
                    currentUser = nil
                    isDeviceBlocked = true
                    errorMessage = deviceCheck.error ?? L10n.errorDeviceBlocked
                    isLoading = false
                    return
                }

                // User doesn't exist, create new one
                var newUser = User(id: userId, deviceId: fingerprint)
                newUser.displayName = firebaseDisplayName
                if deviceCheck.freeCreditsAlreadyClaimed == true {
                    newUser.credits = 0
                    #if DEBUG
                    print("⚠️ [Auth] Device already claimed free credits — starting with 0")
                    #endif
                }
                try await userRepository.createUser(newUser)
                currentUser = newUser
                AnalyticsService.shared.logSignUp(method: "apple")
                #if DEBUG
                print("✅ [Auth] New user created with displayName: \(firebaseDisplayName ?? "nil")")
                #endif
            }

            // Sync encryption key (cross-device support)
            if let user = currentUser {
                await EncryptionService.syncEncryptionKey(userId: userId, user: user, userRepository: userRepository)
            }

        } catch {
            #if DEBUG
            print("❌ [Auth] Apple sign in failed: \(error)")
            #endif
            errorMessage = error.friendlyAuthMessage
        }

        isLoading = false
    }

    /// Sign in/up with Google
    @MainActor
    func signInWithGoogle() async {
        #if DEBUG
        print("🔐 [Auth] Starting Google sign in...")
        #endif
        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authRepository.signInWithGoogle()
            currentUserId = userId
            appLog("Google sign in successful: \(userId)", category: .auth)
            AnalyticsService.shared.setUserId(userId)
            #if DEBUG
            print("✅ [Auth] Google sign in successful. User ID: \(userId)")
            #endif

            // Sync RevenueCat with Firebase user ID
            await RevenueCatManager.shared.login(appUserID: userId)

            // Get display name from Firebase Auth profile (Google sets this automatically)
            let googleDisplayName = Auth.auth().currentUser?.displayName

            // Try to load existing user, if not exists create new one
            let existingUser = try await userRepository.getUser(id: userId)
            if let user = existingUser {
                currentUser = user
                AnalyticsService.shared.logSignIn(method: "google")
                #if DEBUG
                print("✅ [Auth] Existing user loaded")
                #endif

                // Ensure deviceId is saved (may be missing from older accounts)
                if user.deviceId == nil || user.deviceId?.isEmpty == true {
                    let deviceId = KeychainService.getOrCreateDeviceFingerprint()
                    try? await userRepository.updateDeviceId(userId: userId, deviceId: deviceId)
                    #if DEBUG
                    print("📱 [Auth] Backfilled missing deviceId for Google user")
                    #endif
                }

                // Backfill display name if missing in Firestore but available from Firebase Auth
                if (user.displayName == nil || user.displayName?.isEmpty == true),
                   let authName = googleDisplayName, !authName.isEmpty {
                    try? await userRepository.updateProfileInfo(userId: userId, displayName: authName, gender: user.gender ?? "", height: user.height, bodyType: user.bodyType, closetColor: user.closetColor)
                    currentUser?.displayName = authName
                    #if DEBUG
                    print("📝 [Auth] Backfilled missing displayName for Google user: \(authName)")
                    #endif
                }
            } else {
                // Device check — abuse prevention (Keychain + Apple DeviceCheck)
                let fingerprint = KeychainService.getOrCreateDeviceFingerprint()
                let deviceCheck = try await WorkerAPIService.shared.checkDevice(fingerprint: fingerprint)
                if deviceCheck.allowed != true {
                    try? authRepository.signOut()
                    await RevenueCatManager.shared.logout()
                    currentUserId = nil
                    currentUser = nil
                    isDeviceBlocked = true
                    errorMessage = deviceCheck.error ?? L10n.errorDeviceBlocked
                    isLoading = false
                    return
                }

                // User doesn't exist, create new one
                var newUser = User(id: userId, deviceId: fingerprint)
                newUser.displayName = googleDisplayName
                if deviceCheck.freeCreditsAlreadyClaimed == true {
                    newUser.credits = 0
                    #if DEBUG
                    print("⚠️ [Auth] Device already claimed free credits — starting with 0")
                    #endif
                }
                try await userRepository.createUser(newUser)
                currentUser = newUser
                AnalyticsService.shared.logSignUp(method: "google")
                #if DEBUG
                print("✅ [Auth] New user created with displayName: \(googleDisplayName ?? "nil")")
                #endif
            }

            // Sync encryption key (cross-device support)
            if let user = currentUser {
                await EncryptionService.syncEncryptionKey(userId: userId, user: user, userRepository: userRepository)
            }

        } catch {
            #if DEBUG
            print("❌ [Auth] Google sign in failed: \(error)")
            #endif
            errorMessage = error.friendlyAuthMessage
        }

        isLoading = false
    }

    // MARK: - Anonymous Sign In

    /// Create an anonymous account automatically (for first launch)
    @MainActor
    func signInAnonymously() async {
        #if DEBUG
        print("🔐 [Auth] Starting anonymous sign in...")
        #endif
        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authRepository.signInAnonymously()
            currentUserId = userId
            appLog("Anonymous sign in successful: \(userId)", category: .auth)
            AnalyticsService.shared.logSignUp(method: "anonymous")
            AnalyticsService.shared.setUserId(userId)

            // Sync RevenueCat
            await RevenueCatManager.shared.login(appUserID: userId)

            // Device check
            let fingerprint = KeychainService.getOrCreateDeviceFingerprint()
            let deviceCheck = try await WorkerAPIService.shared.checkDevice(fingerprint: fingerprint)
            if deviceCheck.allowed != true {
                try? authRepository.signOut()
                await RevenueCatManager.shared.logout()
                currentUserId = nil
                currentUser = nil
                isDeviceBlocked = true
                errorMessage = deviceCheck.error ?? L10n.errorDeviceBlocked
                isLoading = false
                return
            }

            // Create Firestore user doc
            var newUser = User(id: userId, deviceId: fingerprint)
            if deviceCheck.freeCreditsAlreadyClaimed == true {
                newUser.credits = 0
                didDetectCreditAbuse = true
                #if DEBUG
                print("⚠️ [Auth] Device already claimed free credits — starting with 0")
                #endif
            }
            try await userRepository.createUser(newUser)
            currentUser = newUser

            // Sync encryption key
            await EncryptionService.syncEncryptionKey(userId: userId, user: newUser, userRepository: userRepository)

            #if DEBUG
            print("✅ [Auth] Anonymous sign in complete. User ID: \(userId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Auth] Anonymous sign in failed: \(error)")
            #endif
            errorMessage = error.friendlyAuthMessage
        }

        isLoading = false
    }

    // MARK: - Account Linking

    /// Check if user is anonymous and show linking sheet. Returns true if NOT anonymous (action can proceed).
    @MainActor
    func requireAccountLinking(context: AccountLinkingContext) -> Bool {
        guard isAnonymous else { return true }
        accountLinkingContext = context
        showAccountLinkingSheet = true
        return false
    }

    /// Link anonymous account with Apple
    @MainActor
    func linkWithApple() async {
        #if DEBUG
        print("🔗 [Auth] Linking anonymous account with Apple...")
        #endif
        isLinking = true
        linkingProvider = .apple
        errorMessage = nil
        isCredentialInUseError = false

        do {
            let userId = try await authRepository.linkWithApple()
            #if DEBUG
            print("✅ [Auth] Apple link successful. UID preserved: \(userId)")
            #endif

            // Update display name from Firebase Auth
            if let displayName = Auth.auth().currentUser?.displayName, !displayName.isEmpty {
                try? await userRepository.updateProfileInfo(
                    userId: userId,
                    displayName: displayName,
                    gender: currentUser?.gender ?? "",
                    height: currentUser?.height,
                    bodyType: currentUser?.bodyType,
                    closetColor: currentUser?.closetColor
                )
                currentUser?.displayName = displayName
            }

            AnalyticsService.shared.logSignIn(method: "apple_link")
            await loadCurrentUser()
            showAccountLinkingSheet = false
        } catch {
            #if DEBUG
            print("❌ [Auth] Apple link failed: \(error)")
            #endif
            errorMessage = error.friendlyAuthMessage
            isCredentialInUseError = isCredentialConflictError(error)
            if isCredentialInUseError && prefillEmail == nil {
                prefillEmail = (error as NSError).userInfo["FIRAuthErrorUserInfoEmailKey"] as? String
            }
        }

        isLinking = false
        linkingProvider = nil
    }

    /// Link anonymous account with Google
    @MainActor
    func linkWithGoogle() async {
        #if DEBUG
        print("🔗 [Auth] Linking anonymous account with Google...")
        #endif
        isLinking = true
        linkingProvider = .google
        errorMessage = nil
        isCredentialInUseError = false

        do {
            let userId = try await authRepository.linkWithGoogle()
            #if DEBUG
            print("✅ [Auth] Google link successful. UID preserved: \(userId)")
            #endif

            // Update display name from Firebase Auth
            if let displayName = Auth.auth().currentUser?.displayName, !displayName.isEmpty {
                try? await userRepository.updateProfileInfo(
                    userId: userId,
                    displayName: displayName,
                    gender: currentUser?.gender ?? "",
                    height: currentUser?.height,
                    bodyType: currentUser?.bodyType,
                    closetColor: currentUser?.closetColor
                )
                currentUser?.displayName = displayName
            }

            AnalyticsService.shared.logSignIn(method: "google_link")
            await loadCurrentUser()
            showAccountLinkingSheet = false
        } catch {
            #if DEBUG
            print("❌ [Auth] Google link failed: \(error)")
            #endif
            errorMessage = error.friendlyAuthMessage
            isCredentialInUseError = isCredentialConflictError(error)
            // Get email from Google sign-in or error userInfo
            if isCredentialInUseError && prefillEmail == nil {
                prefillEmail = GIDSignIn.sharedInstance.currentUser?.profile?.email
                    ?? (error as NSError).userInfo["FIRAuthErrorUserInfoEmailKey"] as? String
            }
        }

        isLinking = false
        linkingProvider = nil
    }

    func linkWithEmail(email: String, password: String) async {
        isLinking = true
        linkingProvider = nil
        errorMessage = nil

        do {
            let userId = try await authRepository.linkWithEmail(email: email, password: password)

            AnalyticsService.shared.logSignIn(method: "email_link")
            await loadCurrentUser()
            showAccountLinkingSheet = false
        } catch {
            errorMessage = error.friendlyAuthMessage
        }

        isLinking = false
    }

    private func isCredentialConflictError(_ error: Error) -> Bool {
        if (error as? AuthError) == .credentialAlreadyInUse { return true }
        let nsError = error as NSError
        let code = nsError.code
        // Extract email from Firebase error userInfo
        if let email = nsError.userInfo["FIRAuthErrorUserInfoEmailKey"] as? String {
            prefillEmail = email
        }
        // 17025 = credentialAlreadyInUse, 17012 = accountExistsWithDifferentCredential, 17007 = emailAlreadyInUse
        return code == 17025 || code == 17012 || code == 17007
    }

    /// Load current user from Firestore
    @MainActor
    func loadCurrentUser() async {
        guard let userId = currentUserId else {
            #if DEBUG
            print("⚠️ [Auth] No user ID to load")
            #endif
            return
        }

        #if DEBUG
        print("🔐 [Auth] Loading user from Firestore: \(userId)")
        #endif
        do {
            currentUser = try await userRepository.getUser(id: userId)
            #if DEBUG
            print("✅ [Auth] User loaded successfully")
            if let user = currentUser {
                print("   - Has model image: \(user.hasModelImage)")
                print("   - Model image path: \(user.modelImagePath ?? "nil")")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ [Auth] Failed to load user: \(error)")
            #endif
            errorMessage = L10n.errorUserLoadFailed
        }
    }

    /// Sign out
    @MainActor
    func signOut() async {
        do {
            try authRepository.signOut()
            AnalyticsService.shared.logSignOut()
            AnalyticsService.shared.clearUserId()
            // Logout from RevenueCat (resets to anonymous)
            await RevenueCatManager.shared.logout()
            currentUserId = nil
            currentUser = nil
            #if DEBUG
            print("✅ [Auth] User signed out")
            #endif
        } catch {
            errorMessage = L10n.authSignOutFailed
            #if DEBUG
            print("❌ [Auth] Sign out failed: \(error)")
            #endif
        }
    }

    // MARK: - Referral

    /// Process a referral code after sign-up. Returns error message if failed, nil on success.
    @MainActor
    func processReferralCode(_ code: String) async -> String? {
        guard let userId = currentUserId else { return nil }

        do {
            try await referralRepository.processReferral(newUserId: userId, referralCode: code)
            #if DEBUG
            print("✅ [Auth] Referral code processed successfully")
            #endif
            await loadCurrentUser()
            return nil
        } catch {
            #if DEBUG
            print("⚠️ [Auth] Referral code error: \(error.localizedDescription)")
            #endif
            return error.localizedDescription
        }
    }

    /// Check authentication state and load user if needed
    @MainActor
    func checkAuthState() async {
        #if DEBUG
        print("🔐 [Auth] Checking auth state...")
        #endif
        if let userId = authRepository.getCurrentUserId() {
            #if DEBUG
            print("✅ [Auth] Existing user found: \(userId)")
            #endif
            currentUserId = userId

            // Sync RevenueCat with Firebase user ID
            await RevenueCatManager.shared.login(appUserID: userId)

            await loadCurrentUser()

            // Sync encryption key (cross-device support)
            if let user = currentUser {
                await EncryptionService.syncEncryptionKey(userId: userId, user: user, userRepository: userRepository)
            }

            // Sync Pro credits (renewal, cancellation, first-time)
            await syncProCreditsIfNeeded(userId: userId)
        } else {
            #if DEBUG
            print("ℹ️ [Auth] No existing user, will show welcome screen")
            #endif
            // No auto sign in - user must choose auth method
        }
    }

    // MARK: - Pro Credit Sync

    @MainActor
    private func syncProCreditsIfNeeded(userId: String) async {
        // Sync Pro status via Worker (server-side Firestore update)
        do {
            try await WorkerAPIService.shared.syncPro()
            await loadCurrentUser()
            #if DEBUG
            print("✅ [Auth] Pro status synced via Worker")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [Auth] Worker syncPro failed: \(error.localizedDescription)")
            #endif
        }
    }
}
