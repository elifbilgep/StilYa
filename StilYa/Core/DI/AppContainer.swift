//
//  AppContainer.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//  Updated: 2026-02-11 - Cleaned up unused AI services
//

import Foundation
import SwiftUI
import FirebaseCore
import Combine

final class AppContainer: ObservableObject {
    // MARK: - Services
    let authService: FirebaseAuthService
    let firestoreService: FirestoreService
    let storageService: R2StorageService

    // AI Services
    let tryOnService: TryOnService

    // MARK: - Repositories
    let authRepository: AuthRepository
    let userRepository: UserRepository
    let garmentRepository: GarmentRepository
    let lookRepository: LookRepository
    let storageRepository: StorageRepository
    let referralRepository: ReferralRepository

    // MARK: - Shared ViewModels
    @Published var authViewModel: AuthViewModel?
    @Published var looksViewModel: LooksViewModel?
    @Published var closetViewModel: ClosetViewModel?

    // MARK: - Callbacks
    var onLogout: (() -> Void)?

    // MARK: - Initialization
    init() {
        // Ensure Firebase is configured before creating services
        if FirebaseApp.app() == nil {
            #if DEBUG
            print("⚠️ Warning: Firebase not configured yet, configuring now...")
            #endif
            FirebaseApp.configure()
        }

        // Initialize Services
        self.authService = FirebaseAuthService()
        self.firestoreService = FirestoreService()
        self.storageService = R2StorageService()  // Cloudflare R2

        // Initialize AI Services
        self.tryOnService = TryOnService.shared
        #if DEBUG
        print("🤖 AI Services: fal Model APIs (via worker)")
        #endif

        // Initialize Repositories
        self.authRepository = authService
        self.storageRepository = storageService
        self.userRepository = UserRepositoryImpl(
            firestoreService: firestoreService,
            storageRepository: storageService
        )
        self.garmentRepository = GarmentRepositoryImpl(firestoreService: firestoreService)
        self.lookRepository = LookRepositoryImpl(firestoreService: firestoreService)
        self.referralRepository = ReferralRepositoryImpl(
            firestoreService: firestoreService,
            userRepository: self.userRepository
        )

        #if DEBUG
        print("✅ AppContainer initialized successfully")
        print("🎯 AI: fal Model APIs (via worker)")
        #endif
    }

    // MARK: - Shared ViewModel Setup

    /// Clear memory caches when app goes to background
    func cleanupOnBackground() {
        looksViewModel?.clearMemoryCaches()
        #if DEBUG
        print("[AppContainer] Background cleanup: memory caches cleared")
        #endif
    }

    /// Initialize AuthViewModel (call from SplashView)
    func initializeAuthViewModel() {
        guard authViewModel == nil else { return }
        authViewModel = AuthViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            referralRepository: referralRepository
        )
    }

    /// Initialize and load looks once (call from SplashView)
    func initializeLooksViewModel() {
        guard looksViewModel == nil else { return }
        looksViewModel = LooksViewModel(
            authRepository: authRepository,
            lookRepository: lookRepository,
            storageRepository: storageRepository
        )
    }

    /// Reset cached ViewModels on sign out (eski hesap verileri temizlenir)
    @MainActor
    func resetOnLogout() {
        // Clear disk + memory caches before releasing VM
        looksViewModel?.clearAllCaches()
        authViewModel = nil
        looksViewModel = nil
        closetViewModel = nil
        #if DEBUG
        print("🧹 [AppContainer] ViewModels reset + caches cleared on logout")
        #endif
    }

    /// Initialize closet VM and preload garments + model image (call from SplashView)
    @MainActor
    func initializeClosetViewModel(userId: String) {
        guard closetViewModel == nil else { return }
        closetViewModel = ClosetViewModel(
            garmentRepository: garmentRepository,
            userRepository: userRepository,
            storageRepository: storageRepository,
            lookRepository: lookRepository,
            tryOnService: tryOnService,
            currentUserId: userId
        )
        Task {
            await closetViewModel?.loadClosetData()
        }
    }

}
