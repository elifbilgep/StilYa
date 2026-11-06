//
//  LooksViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import Foundation
import SwiftUI
import CryptoKit
import ImageIO

@Observable
@MainActor
final class LooksViewModel {
    // MARK: - Properties
    private let authRepository: AuthRepository
    private let lookRepository: LookRepository
    private let storageRepository: StorageRepository

    var looks: [Look] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMoreLooks = false
    var errorMessage: String?

    private let pageSize = 20

    // MARK: - Memory-Managed Image Caches (NSCache auto-evicts under memory pressure)
    private let lookImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 30  // Max 30 thumbnails in memory
        cache.totalCostLimit = 30 * 1024 * 1024  // ~30MB max for thumbnails
        return cache
    }()

    private let garmentImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 40  // Max 40 garment thumbnails
        cache.totalCostLimit = 10 * 1024 * 1024  // ~10MB max
        return cache
    }()

    // Track which IDs have been loaded (NSCache doesn't expose keys)
    private var loadedLookImageIds: Set<String> = []
    private var loadedGarmentImageIds: Set<String> = []

    // Prevent duplicate concurrent loads (fixes re-render → re-download loop)
    private var loadingLookImageIds: Set<String> = []
    private var loadingGarmentImageIds: Set<String> = []

    // Track failed loads to show error state instead of infinite spinner
    private var failedLookImageIds: Set<String> = []

    // Thumbnail sizes for grid/detail views
    private static let gridThumbnailMaxSize: CGFloat = 400  // 200pt @ 2x
    private static let garmentThumbnailMaxSize: CGFloat = 200  // 56pt @ 3x+

    // Observable wrappers for SwiftUI (updated when images load)
    var lookImagesVersion: Int = 0
    var garmentImagesVersion: Int = 0

    /// Get look image from cache
    func lookImage(for lookId: String) -> UIImage? {
        lookImageCache.object(forKey: lookId as NSString)
    }

    /// Get garment image from cache
    func garmentImage(for garmentId: String) -> UIImage? {
        garmentImageCache.object(forKey: garmentId as NSString)
    }

    /// Check if a look image failed to load (show error state instead of spinner)
    func isLookImageFailed(_ lookId: String) -> Bool {
        failedLookImageIds.contains(lookId)
    }

    /// Full resolution image for detail view (reads from disk cache)
    func lookImageFullRes(for look: Look) -> UIImage? {
        if let data = loadDataFromDiskCache(key: look.resultImagePath) {
            return autoreleasepool { UIImage(data: data) }
        }
        // Fallback to thumbnail from memory cache
        return lookImageCache.object(forKey: look.id as NSString)
    }

    // MARK: - Disk Cache
    private static let cacheDirectoryName = "LookImageCache"
    private static let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private var cacheDirectory: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = caches.appendingPathComponent(Self.cacheDirectoryName)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Lifecycle Observers
    nonisolated(unsafe) private var memoryWarningObserver: Any?

    // MARK: - Initialization
    init(
        authRepository: AuthRepository,
        lookRepository: LookRepository,
        storageRepository: StorageRepository
    ) {
        self.authRepository = authRepository
        self.lookRepository = lookRepository
        self.storageRepository = storageRepository

        // Listen for memory warnings and clear caches
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearMemoryCaches()
        }

        // Only clear caches on memory warning, NOT on background
        // (disk cache provides fast reload, but re-downloading from R2 is slow)
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        lookImageCache.removeAllObjects()
        garmentImageCache.removeAllObjects()
    }

    /// Clear all in-memory caches (keeps disk cache)
    func clearMemoryCaches() {
        lookImageCache.removeAllObjects()
        garmentImageCache.removeAllObjects()
        loadedLookImageIds.removeAll()
        loadedGarmentImageIds.removeAll()
        loadingLookImageIds.removeAll()
        loadingGarmentImageIds.removeAll()
        failedLookImageIds.removeAll()
        #if DEBUG
        print("🧹 [LooksVM] Memory caches cleared")
        #endif
    }

    /// Clear all caches including disk (call on logout)
    func clearAllCaches() {
        clearMemoryCaches()
        // Delete disk cache directory
        if let cacheDir = cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDir)
        }
        #if DEBUG
        print("🧹 [LooksVM] All caches cleared (memory + disk)")
        #endif
    }

    // MARK: - Load Looks (metadata only, images loaded separately)
    @MainActor
    func loadLooks(limit: Int? = nil) async {
        // Sadece ilk yüklemede spinner göster, refresh'te gösterme
        if looks.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            guard let userId = authRepository.getCurrentUserId() else {
                #if DEBUG
                print("❌ [LooksVM] No user ID")
                #endif
                isLoading = false
                return
            }

            // Use explicit limit if provided (e.g. HomeView recent looks),
            // otherwise use pageSize for paginated gallery
            let queryLimit = limit ?? pageSize

            #if DEBUG
            print("🔵 [LooksVM] Loading looks for user: \(userId) (limit: \(queryLimit))")
            #endif

            // Fetch looks metadata from Firestore with server-side limit
            let fetchedLooks = try await lookRepository.getLooks(userId: userId, limit: queryLimit)
            looks = fetchedLooks
            hasMoreLooks = fetchedLooks.count >= queryLimit && limit == nil

            #if DEBUG
            print("✅ [LooksVM] Loaded \(looks.count) looks metadata, hasMore: \(hasMoreLooks)")
            #endif
            isLoading = false

        } catch {
            #if DEBUG
            print("❌ [LooksVM] Error loading looks: \(error)")
            #endif
            errorMessage = L10n.looksLoadError
            isLoading = false
        }
    }

    // MARK: - Load More Looks
    @MainActor
    func loadMoreLooks() async {
        guard hasMoreLooks, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            guard let userId = authRepository.getCurrentUserId() else {
                isLoadingMore = false
                return
            }

            let nextPageSize = looks.count + pageSize

            #if DEBUG
            print("🔵 [LooksVM] Loading more looks (total: \(nextPageSize))")
            #endif

            let fetchedLooks = try await lookRepository.getLooks(userId: userId, limit: nextPageSize)
            looks = fetchedLooks
            hasMoreLooks = fetchedLooks.count >= nextPageSize

            #if DEBUG
            print("✅ [LooksVM] Loaded \(looks.count) looks total, hasMore: \(hasMoreLooks)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [LooksVM] Error loading more looks: \(error)")
            #endif
        }

        isLoadingMore = false
    }

    // MARK: - Reload Evicted Images (after app returns from background)
    /// NSCache arka planda boşaltılmış olabilir — disk cache'ten hızlıca geri yükle
    @MainActor
    func reloadEvictedImages() async {
        var reloadedCount = 0
        for look in looks {
            // Zaten memory cache'te varsa atla
            if lookImageCache.object(forKey: look.id as NSString) != nil { continue }

            // Disk cache'ten yükle (network çağrısı yok, hızlı)
            if let diskData = loadDataFromDiskCache(key: look.resultImagePath) {
                let thumbnail: UIImage? = autoreleasepool {
                    downsampleImage(data: diskData, maxPixelSize: Self.gridThumbnailMaxSize)
                        ?? UIImage(data: diskData)
                }
                if let thumbnail {
                    let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    lookImageCache.setObject(thumbnail, forKey: look.id as NSString, cost: cost)
                    loadedLookImageIds.insert(look.id)
                    reloadedCount += 1
                }
            }
        }
        if reloadedCount > 0 {
            lookImagesVersion += 1
            #if DEBUG
            print("🔄 [LooksVM] Reloaded \(reloadedCount) evicted images from disk cache")
            #endif
        }
    }

    // MARK: - Load Recent Look Images (for HomeView - only first 3)
    @MainActor
    func loadRecentLookImages(count: Int = 3) async {
        let recentToLoad = Array(looks.prefix(count))

        for look in recentToLoad {
            await loadLookImage(look)
        }
    }

    // MARK: - Load All Look Images (for LooksView gallery)
    @MainActor
    func loadAllLookImages() async {
        // Load images with limited concurrency to avoid overwhelming the server
        let maxConcurrent = 4
        let looksToLoad = looks.filter { lookImageCache.object(forKey: $0.id as NSString) == nil }

        // Load in batches to avoid rate limiting / timeout
        for batch in stride(from: 0, to: looksToLoad.count, by: maxConcurrent) {
            let end = min(batch + maxConcurrent, looksToLoad.count)
            let currentBatch = Array(looksToLoad[batch..<end])

            await withTaskGroup(of: Void.self) { group in
                for look in currentBatch {
                    group.addTask { [weak self] in
                        await self?.loadLookImage(look)
                    }
                }
            }
        }
    }

    // MARK: - Load Look Image (with disk cache + retry + downsampling)
    @MainActor
    func loadLookImage(_ look: Look, retryCount: Int = 2) async {
        // Skip if already in memory
        if lookImageCache.object(forKey: look.id as NSString) != nil {
            return
        }

        // Skip if already loading (prevent duplicate concurrent loads / re-render loops)
        guard !loadingLookImageIds.contains(look.id) else { return }
        loadingLookImageIds.insert(look.id)
        defer { loadingLookImageIds.remove(look.id) }

        // Try disk cache first → create thumbnail
        if let diskData = loadDataFromDiskCache(key: look.resultImagePath) {
            let thumbnail: UIImage? = autoreleasepool {
                downsampleImage(data: diskData, maxPixelSize: Self.gridThumbnailMaxSize)
                    ?? UIImage(data: diskData) // fallback if downsample fails
            }
            if let thumbnail {
                let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                lookImageCache.setObject(thumbnail, forKey: look.id as NSString, cost: cost)
                loadedLookImageIds.insert(look.id)
                failedLookImageIds.remove(look.id)
                lookImagesVersion += 1
            }
            #if DEBUG
            print("💾 [LooksVM] Cache hit (thumbnail) for look: \(look.id)")
            #endif
            return
        }

        // Download with retry
        for attempt in 0...retryCount {
            do {
                #if DEBUG
                if attempt > 0 {
                    print("🔄 [LooksVM] Retry \(attempt)/\(retryCount) for look: \(look.id)")
                } else {
                    print("🔵 [LooksVM] Downloading image for look: \(look.id)")
                }
                #endif

                let imageData = try await storageRepository.downloadImage(path: look.resultImagePath)

                // Save full resolution to disk cache
                saveToDiskCache(key: look.resultImagePath, data: imageData)

                // Create downsampled thumbnail for grid (saves memory)
                let thumbnail: UIImage? = autoreleasepool {
                    downsampleImage(data: imageData, maxPixelSize: Self.gridThumbnailMaxSize)
                        ?? UIImage(data: imageData) // fallback if downsample fails
                }
                if let thumbnail {
                    let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    lookImageCache.setObject(thumbnail, forKey: look.id as NSString, cost: cost)
                    loadedLookImageIds.insert(look.id)
                    failedLookImageIds.remove(look.id)
                    lookImagesVersion += 1
                }

                #if DEBUG
                print("✅ [LooksVM] Thumbnail loaded for look: \(look.id)")
                #endif
                return // Success — exit retry loop

            } catch {
                #if DEBUG
                print("❌ [LooksVM] Error loading image for look \(look.id) (attempt \(attempt)): \(error)")
                #endif

                if attempt < retryCount {
                    // Exponential backoff: 1s, 2s
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        // All retries failed — mark as failed to prevent infinite spinner
        failedLookImageIds.insert(look.id)
        lookImagesVersion += 1
    }

    // MARK: - Load Garment Images
    @MainActor
    func loadGarmentImages(for look: Look) async {
        for garment in look.garments {
            if garmentImageCache.object(forKey: garment.id as NSString) != nil { continue }

            // Skip if already loading
            guard !loadingGarmentImageIds.contains(garment.id) else { continue }

            // Skip if imagePath is empty (legacy data from before fix)
            guard !garment.imagePath.isEmpty else {
                #if DEBUG
                print("⚠️ [LooksVM] Garment \(garment.id) has empty imagePath (legacy data), skipping")
                #endif
                continue
            }

            loadingGarmentImageIds.insert(garment.id)

            // Try disk cache → create thumbnail
            if let diskData = loadDataFromDiskCache(key: garment.imagePath) {
                let thumbnail: UIImage? = autoreleasepool {
                    downsampleImage(data: diskData, maxPixelSize: Self.garmentThumbnailMaxSize)
                }
                if let thumbnail {
                    let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    garmentImageCache.setObject(thumbnail, forKey: garment.id as NSString, cost: cost)
                    loadedGarmentImageIds.insert(garment.id)
                    garmentImagesVersion += 1
                }
                loadingGarmentImageIds.remove(garment.id)
                continue
            }

            do {
                let imageData = try await storageRepository.downloadImage(path: garment.imagePath)
                saveToDiskCache(key: garment.imagePath, data: imageData)
                let thumbnail: UIImage? = autoreleasepool {
                    downsampleImage(data: imageData, maxPixelSize: Self.garmentThumbnailMaxSize)
                }
                if let thumbnail {
                    let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    garmentImageCache.setObject(thumbnail, forKey: garment.id as NSString, cost: cost)
                    loadedGarmentImageIds.insert(garment.id)
                    garmentImagesVersion += 1
                }
            } catch {
                #if DEBUG
                print("❌ [LooksVM] Error loading garment image \(garment.id): \(error)")
                #endif
            }
            loadingGarmentImageIds.remove(garment.id)
        }
    }

    // MARK: - Toggle Favorite
    @MainActor
    func toggleFavorite(_ look: Look) async {
        guard let userId = authRepository.getCurrentUserId() else {
            return
        }

        do {
            #if DEBUG
            print("🔵 [LooksVM] Toggling favorite for look: \(look.id)")
            #endif
            try await lookRepository.toggleFavorite(lookId: look.id, userId: userId)

            // Update local state
            if let index = looks.firstIndex(where: { $0.id == look.id }) {
                looks[index].isFavorite.toggle()
            }

            #if DEBUG
            print("✅ [LooksVM] Favorite toggled")
            #endif

        } catch {
            #if DEBUG
            print("❌ [LooksVM] Error toggling favorite: \(error)")
            #endif
            errorMessage = L10n.looksFavoriteError
        }
    }

    // MARK: - Delete Look
    @MainActor
    func deleteLook(_ look: Look) async {
        guard let userId = authRepository.getCurrentUserId() else {
            return
        }

        do {
            #if DEBUG
            print("🔵 [LooksVM] Deleting look: \(look.id)")
            #endif

            // Delete from Firestore
            try await lookRepository.deleteLook(id: look.id, userId: userId)

            // Remove from local state
            looks.removeAll { $0.id == look.id }
            lookImageCache.removeObject(forKey: look.id as NSString)
            loadedLookImageIds.remove(look.id)
            failedLookImageIds.remove(look.id)
            lookImagesVersion += 1

            // Remove from disk cache
            removeFromDiskCache(key: look.resultImagePath)

            #if DEBUG
            print("✅ [LooksVM] Look deleted")
            #endif

        } catch {
            #if DEBUG
            print("❌ [LooksVM] Error deleting look: \(error)")
            #endif
            errorMessage = L10n.looksDeleteError
        }
    }

    // MARK: - Get Recent Looks
    var recentLooks: [Look] {
        Array(looks.prefix(3))
    }

    // MARK: - Get Closet Looks
    var closetLooks: [Look] {
        looks.filter { $0.source == .closet }
    }

    // MARK: - Get Favorite Looks
    var favoriteLooks: [Look] {
        looks.filter { $0.isFavorite }
    }

    // MARK: - Image Downsampling

    /// Downsample image data to a thumbnail for memory-efficient grid display
    private func downsampleImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Disk Cache Helpers

    private func cacheFileName(for key: String) -> String {
        // Hash the path to create a safe filename
        let data = Data(key.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func saveToDiskCache(key: String, data: Data) {
        guard let cacheDir = cacheDirectory else { return }
        let fileURL = cacheDir.appendingPathComponent(cacheFileName(for: key))
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadFromDiskCache(key: String) -> (image: UIImage, dataSize: Int)? {
        guard let data = loadDataFromDiskCache(key: key) else { return nil }
        guard let image = UIImage(data: data) else { return nil }
        return (image, data.count)
    }

    /// Load raw data from disk cache (for downsampling)
    private func loadDataFromDiskCache(key: String) -> Data? {
        guard let cacheDir = cacheDirectory else { return nil }
        let fileURL = cacheDir.appendingPathComponent(cacheFileName(for: key))

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        // Check cache age
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) > Self.maxCacheAge {
            // Cache expired
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    private func removeFromDiskCache(key: String) {
        guard let cacheDir = cacheDirectory else { return }
        let fileURL = cacheDir.appendingPathComponent(cacheFileName(for: key))
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Clean up old cache files (call periodically)
    func cleanExpiredCache() {
        guard let cacheDir = cacheDirectory else { return }

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

        for fileURL in files {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let modDate = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) > Self.maxCacheAge {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
