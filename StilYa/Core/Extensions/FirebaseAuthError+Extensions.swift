//
//  FirebaseAuthError+Extensions.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 14.12.2025.
//

import Foundation
import FirebaseAuth

extension Error {
    /// Convert Firebase Auth error to user-friendly localized message
    var friendlyAuthMessage: String {
        // Handle custom AuthError first
        if let authError = self as? AuthError {
            return authError.localizedDescription
        }

        let nsError = self as NSError

        guard nsError.domain == AuthErrorDomain else {
            return L10n.errorGeneric
        }

        guard let errorCode = AuthErrorCode(rawValue: nsError.code) else {
            return L10n.errorGeneric
        }

        switch errorCode {
        case .emailAlreadyInUse:
            return L10n.errorEmailInUse
        case .invalidEmail:
            return L10n.errorInvalidEmail
        case .weakPassword:
            return L10n.errorWeakPassword
        case .wrongPassword:
            return L10n.errorWrongPassword
        case .userNotFound:
            return L10n.errorUserNotFound
        case .userDisabled:
            return L10n.errorUserDisabled
        case .networkError:
            return L10n.errorNetworkError
        case .tooManyRequests:
            return L10n.errorTooManyRequests
        case .invalidCredential:
            return L10n.errorInvalidCredential
        case .credentialAlreadyInUse:
            return L10n.errorCredentialInUse
        case .accountExistsWithDifferentCredential:
            return L10n.errorDifferentCredential
        case .requiresRecentLogin:
            return L10n.errorRecentLogin
        case .invalidAPIKey:
            return L10n.errorInvalidAPIKey
        default:
            return L10n.errorSignInFailed
        }
    }
}
