//
//  TrendsViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//

import SwiftUI
import Combine

@MainActor
class TrendsViewModel: ObservableObject {
    @Published var collections: [TrendCollection] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var selectedCategory: String? = nil
    @Published var downloadingImageURL: String? = nil
    @Published var favoriteImageURLs: Set<String> = []

    /// User's style preferences from onboarding (e.g. ["casual", "streetwear", "minimal"])
    var userStylePreferences: [String] = []

    private let imageCache = NSCache<NSString, UIImage>()
    private var currentPage = 1
    private var hasMore = true
    private var currentGender: String?
    private let pageSize = 10

    private let favoritesKey = "trendFavoriteImageURLs"

    init() {
        imageCache.countLimit = 60
        imageCache.totalCostLimit = 40 * 1024 * 1024
        loadFavorites()
    }

    // MARK: - Favorites

    private func loadFavorites() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favoriteImageURLs = Set(saved)
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteImageURLs), forKey: favoritesKey)
    }

    func isFavorite(_ imageURL: String) -> Bool {
        favoriteImageURLs.contains(imageURL)
    }

    func toggleFavorite(_ imageURL: String) {
        if favoriteImageURLs.contains(imageURL) {
            favoriteImageURLs.remove(imageURL)
        } else {
            favoriteImageURLs.insert(imageURL)
        }
        saveFavorites()
        HapticManager.shared.light()
    }

    /// All favorite image URLs across all collections
    var favoriteOutfits: [(url: String, collection: TrendCollection)] {
        collections.flatMap { collection in
            collection.imageUrls
                .filter { favoriteImageURLs.contains($0) }
                .map { (url: $0, collection: collection) }
        }
    }

    // MARK: - Collections

    /// Collections matching user's style preferences
    var forYouCollections: [TrendCollection] {
        guard !userStylePreferences.isEmpty else { return [] }
        return collections.filter { collection in
            userStylePreferences.contains(collection.category) ||
            collection.tags.contains(where: { userStylePreferences.contains($0) })
        }
    }

    /// Whether to show "For You" section
    var hasForYouSection: Bool {
        !forYouCollections.isEmpty
    }

    var filteredCollections: [TrendCollection] {
        guard let cat = selectedCategory else { return collections }
        return collections.filter { $0.category == cat }
    }

    var categories: [String] {
        Array(Set(collections.map { $0.category })).sorted()
    }

    /// Fresh load — resets pagination and fetches first page
    func loadCollections(gender: String? = nil) async {
        isLoading = true
        currentPage = 1
        hasMore = true
        currentGender = gender

        let response = await WorkerAPIService.shared.fetchTrendCollections(
            gender: gender, page: 1, limit: pageSize
        )
        collections = response.collections
        hasMore = response.hasMore ?? false
        currentPage = 1
        isLoading = false
    }

    /// Load next page (append to existing collections)
    func loadMoreIfNeeded(currentItem: TrendCollection?) async {
        guard let item = currentItem else { return }
        let thresholdIndex = max(0, collections.count - 3)
        guard let itemIndex = collections.firstIndex(where: { $0.id == item.id }),
              itemIndex >= thresholdIndex else { return }

        await loadMore()
    }

    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        isLoadingMore = true

        let nextPage = currentPage + 1
        let response = await WorkerAPIService.shared.fetchTrendCollections(
            gender: currentGender, page: nextPage, limit: pageSize
        )

        let existingIds = Set(collections.map { $0.id })
        let newCollections = response.collections.filter { !existingIds.contains($0.id) }
        collections.append(contentsOf: newCollections)
        hasMore = response.hasMore ?? false
        currentPage = nextPage
        isLoadingMore = false
    }

    func cachedImage(for url: String) -> UIImage? {
        imageCache.object(forKey: url as NSString)
    }

    func downloadImage(from urlString: String) async -> UIImage? {
        if let cached = imageCache.object(forKey: urlString as NSString) {
            return cached
        }

        downloadingImageURL = urlString
        defer { downloadingImageURL = nil }

        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                let cost = data.count
                imageCache.setObject(image, forKey: urlString as NSString, cost: cost)
                return image
            }
        } catch {
            print("[TrendsVM] Image download error: \(error)")
        }
        return nil
    }
}
