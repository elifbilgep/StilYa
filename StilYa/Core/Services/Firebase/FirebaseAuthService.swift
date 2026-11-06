//
//  FirebaseAuthService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

class FirebaseAuthService: NSObject, AuthRepository {
    private let auth = Auth.auth()

    // Apple Sign In
    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<String, Error>?

    // Apple Re-authentication (returns credential instead of signing in)
    private var appleCredentialContinuation: CheckedContinuation<AuthCredential, Error>?

    // Apple Linking (returns credential for link instead of sign-in)
    private var appleLinkContinuation: CheckedContinuation<AuthCredential, Error>?

    // MARK: - Sign In with Email
    func signInWithEmail(email: String, password: String) async throws -> String {
        let result = try await auth.signIn(withEmail: email, password: password)
        return result.user.uid
    }

    // MARK: - Sign Up with Email
    func signUpWithEmail(email: String, password: String) async throws -> String {
        let result = try await auth.createUser(withEmail: email, password: password)
        return result.user.uid
    }

    // MARK: - Sign In with Apple
    func signInWithApple() async throws -> String {
        // Generate nonce before continuation (throws on failure)
        let nonce = try randomNonceString()

        return try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation
            self.currentNonce = nonce

            // Create Apple Sign In request
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            // Present authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self

            DispatchQueue.main.async {
                authorizationController.performRequests()
            }
        }
    }

    // MARK: - Helper Methods

    private func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            throw AuthError.nonceGenerationFailed
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    // MARK: - Sign In with Google
    func signInWithGoogle() async throws -> String {
        // Get the top view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }

        // Get client ID from Firebase app
        guard let clientID = Auth.auth().app?.options.clientID else {
            throw AuthError.noClientID
        }

        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Start sign in flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.noIDToken
        }

        let accessToken = result.user.accessToken.tokenString

        // Create Firebase credential
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        // Sign in to Firebase
        let authResult = try await auth.signIn(with: credential)
        return authResult.user.uid
    }

    // MARK: - Get Current User ID
    func getCurrentUserId() -> String? {
        return auth.currentUser?.uid
    }

    // MARK: - Sign Out
    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Anonymous Sign In
    func signInAnonymously() async throws -> String {
        let result = try await auth.signInAnonymously()
        return result.user.uid
    }

    // MARK: - Check Anonymous
    func isCurrentUserAnonymous() -> Bool {
        auth.currentUser?.isAnonymous ?? false
    }

    // MARK: - Link with Apple
    func linkWithApple() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthError.noCurrentUser
        }

        let nonce = try randomNonceString()

        let credential: AuthCredential = try await withCheckedThrowingContinuation { continuation in
            self.currentNonce = nonce
            self.appleLinkContinuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self

            DispatchQueue.main.async {
                authorizationController.performRequests()
            }
        }

        do {
            let result = try await user.link(with: credential)
            return result.user.uid
        } catch let error as NSError {
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                throw AuthError.credentialAlreadyInUse
            }
            throw error
        }
    }

    // MARK: - Link with Google
    @MainActor
    func linkWithGoogle() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthError.noCurrentUser
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }

        guard let clientID = Auth.auth().app?.options.clientID else {
            throw AuthError.noClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.noIDToken
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        do {
            let linkResult = try await user.link(with: credential)
            return linkResult.user.uid
        } catch let error as NSError {
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                throw AuthError.credentialAlreadyInUse
            }
            throw error
        }
    }

    // MARK: - Link with Email
    func linkWithEmail(email: String, password: String) async throws -> String {
        guard let user = auth.currentUser, user.isAnonymous else {
            throw AuthError.notAnonymous
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            let result = try await user.link(with: credential)
            return result.user.uid
        } catch let error as NSError {
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                throw AuthError.credentialAlreadyInUse
            }
            throw error
        }
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.noCurrentUser
        }

        do {
            try await user.delete()
            #if DEBUG
            print("✅ [Auth] Firebase Auth account deleted")
            #endif
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                #if DEBUG
                print("⚠️ [Auth] Requires recent login, auto re-authenticating...")
                #endif
                // Auto re-authenticate based on provider, then retry delete
                try await reauthenticateCurrentUser()
                try await user.delete()
                #if DEBUG
                print("✅ [Auth] Firebase Auth account deleted after re-auth")
                #endif
            } else {
                throw error
            }
        }
    }

    // MARK: - Re-authentication

    private func reauthenticateCurrentUser() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.noCurrentUser
        }

        // Detect sign-in provider
        let providerID = user.providerData.first?.providerID

        #if DEBUG
        print("🔵 [Auth] Re-authenticating with provider: \(providerID ?? "unknown")")
        #endif

        switch providerID {
        case "apple.com":
            try await reauthenticateWithApple(user: user)
        case "google.com":
            try await reauthenticateWithGoogle(user: user)
        case "password":
            try await reauthenticateWithPassword(user: user)
        default:
            throw AuthError.requiresRecentLogin
        }
    }

    private func reauthenticateWithApple(user: FirebaseAuth.User) async throws {
        let nonce = try randomNonceString()

        let credential: AuthCredential = try await withCheckedThrowingContinuation { continuation in
            self.currentNonce = nonce
            self.appleCredentialContinuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self

            DispatchQueue.main.async {
                authorizationController.performRequests()
            }
        }

        try await user.reauthenticate(with: credential)
        #if DEBUG
        print("✅ [Auth] Apple re-authentication successful")
        #endif
    }

    @MainActor
    private func reauthenticateWithGoogle(user: FirebaseAuth.User) async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }

        guard let clientID = Auth.auth().app?.options.clientID else {
            throw AuthError.noClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.noIDToken
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        try await user.reauthenticate(with: credential)
        #if DEBUG
        print("✅ [Auth] Google re-authentication successful")
        #endif
    }

    @MainActor
    private func reauthenticateWithPassword(user: FirebaseAuth.User) async throws {
        guard let email = user.email else {
            throw AuthError.requiresRecentLogin
        }

        let password: String = try await withCheckedThrowingContinuation { continuation in
            let alert = UIAlertController(
                title: L10n.authReauthTitle,
                message: L10n.authReauthMessage,
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = L10n.authPassword
                textField.isSecureTextEntry = true
            }
            alert.addAction(UIAlertAction(title: L10n.commonCancel, style: .cancel) { _ in
                continuation.resume(throwing: AuthError.requiresRecentLogin)
            })
            alert.addAction(UIAlertAction(title: L10n.commonConfirm, style: .default) { _ in
                if let pw = alert.textFields?.first?.text, !pw.isEmpty {
                    continuation.resume(returning: pw)
                } else {
                    continuation.resume(throwing: AuthError.requiresRecentLogin)
                }
            })

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                continuation.resume(throwing: AuthError.noViewController)
                return
            }
            // Present on the topmost view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            topVC.present(alert, animated: true)
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
        #if DEBUG
        print("✅ [Auth] Email/password re-authentication successful")
        #endif
    }
}

// MARK: - Auth Errors
// MARK: - ASAuthorizationControllerDelegate
extension FirebaseAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            appleSignInContinuation?.resume(throwing: AuthError.noIDToken)
            appleSignInContinuation = nil
            appleCredentialContinuation?.resume(throwing: AuthError.noIDToken)
            appleCredentialContinuation = nil
            appleLinkContinuation?.resume(throwing: AuthError.noIDToken)
            appleLinkContinuation = nil
            return
        }

        // Create Firebase credential
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )

        // Link flow: just return the credential
        if let linkContinuation = appleLinkContinuation {
            appleLinkContinuation = nil
            linkContinuation.resume(returning: credential)
            return
        }

        // Re-authentication flow: just return the credential
        if let credContinuation = appleCredentialContinuation {
            appleCredentialContinuation = nil
            credContinuation.resume(returning: credential)
            return
        }

        // Normal sign-in flow
        // Extract display name from Apple credential (only provided on FIRST sign-in)
        let fullName = appleIDCredential.fullName
        var displayName: String?
        if let givenName = fullName?.givenName {
            if let familyName = fullName?.familyName {
                displayName = "\(givenName) \(familyName)"
            } else {
                displayName = givenName
            }
        }

        // Sign in to Firebase
        Task {
            do {
                let authResult = try await auth.signIn(with: credential)

                // Set display name on Firebase Auth profile (Apple doesn't do this automatically)
                if let displayName = displayName, authResult.user.displayName == nil || authResult.user.displayName?.isEmpty == true {
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                    #if DEBUG
                    print("✅ [Auth] Apple display name set on Firebase profile: \(displayName)")
                    #endif
                }

                appleSignInContinuation?.resume(returning: authResult.user.uid)
                appleSignInContinuation = nil
            } catch {
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        #if DEBUG
        print("❌ [Auth] Apple Sign In failed: \(error.localizedDescription)")
        #endif
        appleSignInContinuation?.resume(throwing: error)
        appleSignInContinuation = nil
        appleCredentialContinuation?.resume(throwing: error)
        appleCredentialContinuation = nil
        appleLinkContinuation?.resume(throwing: error)
        appleLinkContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension FirebaseAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case notImplemented
    case noViewController
    case noClientID
    case noIDToken
    case nonceGenerationFailed
    case noCurrentUser
    case requiresRecentLogin
    case credentialAlreadyInUse
    case notAnonymous

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Bu özellik henüz eklenmedi"
        case .noViewController:
            return "Ekran bulunamadı"
        case .noClientID:
            return "Google Client ID bulunamadı"
        case .noIDToken:
            return "Apple/Google giriş token'ı alınamadı"
        case .nonceGenerationFailed:
            return "Güvenlik doğrulaması oluşturulamadı. Lütfen tekrar deneyin"
        case .noCurrentUser:
            return "Oturum açmış kullanıcı bulunamadı"
        case .requiresRecentLogin:
            return "Güvenlik nedeniyle hesabınızı silmeden önce tekrar giriş yapmanız gerekmektedir"
        case .credentialAlreadyInUse:
            return L10n.errorCredentialInUse
        case .notAnonymous:
            return "Bu işlem sadece misafir hesaplar için geçerlidir"
        }
    }
}
