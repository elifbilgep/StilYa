//
//  AuthRepository.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation

protocol AuthRepository {
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws -> String // Returns userId

    /// Sign up with email and password
    func signUpWithEmail(email: String, password: String) async throws -> String // Returns userId

    /// Sign in with Apple
    func signInWithApple() async throws -> String // Returns userId

    /// Sign in with Google
    func signInWithGoogle() async throws -> String // Returns userId

    /// Get current user ID
    func getCurrentUserId() -> String?

    /// Sign out
    func signOut() throws

    /// Delete current user's Firebase Auth account
    func deleteAccount() async throws

    /// Sign in anonymously (creates a new anonymous account)
    func signInAnonymously() async throws -> String // Returns userId

    /// Check if the current user is anonymous
    func isCurrentUserAnonymous() -> Bool

    /// Link anonymous account with Apple credential (preserves UID)
    func linkWithApple() async throws -> String // Returns userId

    /// Link anonymous account with Google credential (preserves UID)
    func linkWithGoogle() async throws -> String // Returns userId

    /// Link anonymous account with email/password (preserves UID)
    func linkWithEmail(email: String, password: String) async throws -> String // Returns userId
}
