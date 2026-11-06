//
//  CartViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 26.12.2025.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class CartViewModel {
    // MARK: - Dependencies
    private let authRepository: AuthRepository
    private let garmentRepository: GarmentRepository
    private let storageRepository: StorageRepository
    private let userRepository: UserRepository

    // MARK: - State
    var cartItems: [Garment] = []
    var isLoading = false
    var errorMessage: String?
    var selectedFilter: GarmentType? = nil // nil = show all
    var selectedItemIds: Set<String> = [] // Selected items for filtered view

    // MARK: - Memory-Managed Image Cache
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 30 * 1024 * 1024 // 30MB
        return cache
    }()
    var imagesVersion: Int = 0

    /// Get garment image from cache
    func garmentImage(for garmentId: String) -> UIImage? {
        imageCache.object(forKey: garmentId as NSString)
    }

    // nonisolated(unsafe) so deinit can remove the observers
    nonisolated(unsafe) private var memoryWarningObserver: Any?
    nonisolated(unsafe) private var backgroundObserver: Any?

    // MARK: - Computed
    var filteredCartItems: [Garment] {
        if let filter = selectedFilter {
            return cartItems.filter { $0.type == filter }
        }
        return cartItems
    }

    var totalPrice: Double {
        // If filter is active, only count selected items
        if selectedFilter != nil {
            return cartItems
                .filter { selectedItemIds.contains($0.id) }
                .compactMap { $0.price }
                .reduce(0, +)
        }
        // If no filter, count all items
        return cartItems.compactMap { $0.price }.reduce(0, +)
    }

    var itemCount: Int {
        // If filter is active, show selected count
        if selectedFilter != nil {
            return selectedItemIds.count
        }
        // If no filter, show all items
        return cartItems.count
    }

    // MARK: - Selection Methods

    func toggleSelection(for garmentId: String) {
        if selectedItemIds.contains(garmentId) {
            selectedItemIds.remove(garmentId)
        } else {
            selectedItemIds.insert(garmentId)
        }
    }

    func isSelected(_ garmentId: String) -> Bool {
        selectedItemIds.contains(garmentId)
    }

    func clearSelection() {
        selectedItemIds.removeAll()
    }

    /// Delete all selected items from cart
    func deleteSelected() async {
        guard let userId = authRepository.getCurrentUserId() else { return }
        let itemsToDelete = cartItems.filter { selectedItemIds.contains($0.id) }

        for garment in itemsToDelete {
            do {
                try await garmentRepository.deleteGarment(id: garment.id, userId: userId)
                try? await storageRepository.deleteImage(path: garment.imagePath)
                imageCache.removeObject(forKey: garment.id as NSString)
            } catch {
                #if DEBUG
                print("❌ [Cart] Failed to delete garment \(garment.id): \(error)")
                #endif
            }
        }

        cartItems.removeAll { selectedItemIds.contains($0.id) }
        selectedItemIds.removeAll()
        imagesVersion += 1
    }

    // MARK: - Initialization
    init(
        authRepository: AuthRepository,
        garmentRepository: GarmentRepository,
        storageRepository: StorageRepository,
        userRepository: UserRepository
    ) {
        self.authRepository = authRepository
        self.garmentRepository = garmentRepository
        self.storageRepository = storageRepository
        self.userRepository = userRepository

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.imageCache.removeAllObjects()
            self?.imagesVersion += 1
            #if DEBUG
            print("🧹 [Cart] Memory caches cleared due to memory warning")
            #endif
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.imageCache.removeAllObjects()
            self?.imagesVersion += 1
            #if DEBUG
            print("🧹 [Cart] Memory caches cleared on background")
            #endif
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Methods

    /// Load cart items from Firestore
    func loadCartItems() async {
        guard let userId = authRepository.getCurrentUserId() else {
            errorMessage = L10n.errorUserNotFound
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            #if DEBUG
            print("🛒 [Cart] Loading cart items...")
            #endif

            // Get all garments
            let allGarments = try await garmentRepository.getGarments(userId: userId)

            // Filter cart items
            cartItems = allGarments.filter { $0.isInCart }

            #if DEBUG
            print("✅ [Cart] Loaded \(cartItems.count) items")
            #endif

            // Load images for each item
            await loadImages(userId: userId)

        } catch {
            #if DEBUG
            print("❌ [Cart] Failed to load cart: \(error.localizedDescription)")
            #endif
            errorMessage = error.localizedDescription
            isLoading = false
        }

        isLoading = false
    }

    /// Load garment images from Storage
    private func loadImages(userId: String) async {
        for garment in cartItems {
            // Skip if already loaded
            guard imageCache.object(forKey: garment.id as NSString) == nil else { continue }

            // Skip if imagePath is empty (legacy data from before fix)
            guard !garment.imagePath.isEmpty else {
                #if DEBUG
                print("⚠️ [Cart] Garment \(garment.id) has empty imagePath (legacy data), skipping")
                #endif
                continue
            }

            do {
                let imageData = try await storageRepository.downloadImage(path: garment.imagePath)
                if let image = UIImage(data: imageData) {
                    imageCache.setObject(image, forKey: garment.id as NSString, cost: imageData.count)
                    imagesVersion += 1
                    #if DEBUG
                    print("✅ [Cart] Image loaded for: \(garment.id)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ [Cart] Failed to load image for \(garment.id): \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Remove item from cart
    func removeFromCart(_ garment: Garment) async {
        guard let userId = authRepository.getCurrentUserId() else { return }

        do {
            #if DEBUG
            print("🗑️ [Cart] Removing item: \(garment.id)")
            #endif

            // Delete from Firestore
            try await garmentRepository.deleteGarment(id: garment.id, userId: userId)

            // Delete image from Storage (optional, to save storage)
            try? await storageRepository.deleteImage(path: garment.imagePath)

            // Update local state
            cartItems.removeAll { $0.id == garment.id }
            imageCache.removeObject(forKey: garment.id as NSString)
            imagesVersion += 1

            #if DEBUG
            print("✅ [Cart] Item removed successfully")
            #endif

        } catch {
            #if DEBUG
            print("❌ [Cart] Failed to remove item: \(error.localizedDescription)")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    /// Open product link in browser
    func openProductLink(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ [Cart] Invalid URL: \(urlString)")
            #endif
            return
        }

        UIApplication.shared.open(url)
    }

    /// Update garment details
    func updateGarment(_ garment: Garment, link: String, brand: String?, price: Double?) async {
        guard let userId = authRepository.getCurrentUserId() else { return }

        do {
            #if DEBUG
            print("✏️ [Cart] Updating garment: \(garment.id)")
            #endif

            // Create updated garment
            var updatedGarment = garment
            updatedGarment.productLink = link
            updatedGarment.brand = brand
            updatedGarment.price = price

            // Update in Firestore
            try await garmentRepository.updateGarment(updatedGarment, userId: userId)

            // Update local state
            if let index = cartItems.firstIndex(where: { $0.id == garment.id }) {
                cartItems[index] = updatedGarment
            }

            #if DEBUG
            print("✅ [Cart] Garment updated successfully")
            #endif

        } catch {
            #if DEBUG
            print("❌ [Cart] Failed to update garment: \(error.localizedDescription)")
            #endif
            errorMessage = error.localizedDescription
        }
    }
}
