//
//  ClosetViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class ClosetViewModel {
    // MARK: - Dependencies
    private let garmentRepository: GarmentRepository
    private let userRepository: UserRepository
    private let storageRepository: StorageRepository
    private let lookRepository: LookRepository
    private let tryOnService: TryOnService
    private let currentUserId: String

    // MARK: - Data
    var allGarments: [Garment] = []
    var modelImage: UIImage?
    var isLoadingGarments = false
    var isLoadingModelImage = false
    var errorMessage: String?

    // MARK: - Pagination
    private let pageSize = 20
    private var lastDocument: Any?
    var hasMoreGarments = true
    var isLoadingMore = false

    // MARK: - Categorized (computed)
    var topAndJacketGarments: [Garment] {
        allGarments.filter { $0.type == .top || $0.type == .jacket }
    }
    var bottomGarments: [Garment] {
        allGarments.filter { $0.type == .bottom }
    }
    var dressGarments: [Garment] {
        allGarments.filter { $0.type == .dress }
    }
    var shoeGarments: [Garment] {
        allGarments.filter { $0.type == .shoes }
    }

    // MARK: - Selection
    var selectedGarments: [GarmentType: Garment] = [:]
    var selectedGarmentImages: [GarmentType: UIImage] = [:]

    var selectedCount: Int {
        selectedGarments.count
    }

    var hasClothingSelected: Bool {
        // At least one non-shoes garment must be selected for try-on
        selectedGarments.contains { $0.key != .shoes }
    }

    var tryOnCreditCost: Int {
        let count = selectedGarments.count
        if count <= 1 { return AppConstants.singleTryOnCost }
        return AppConstants.comboBaseCost
    }

    // MARK: - Try-on
    var isProcessing = false
    var progress: Double = 0.0
    var resultImage: UIImage?
    var currentStep: String = ""
    nonisolated(unsafe) private var progressTask:    Task<Void, Never>?

    // MARK: - Add product
    var showImagePicker = false
    var showGarmentTypePicker = false
    var newGarmentType: GarmentType?
    var isAddingGarment = false

    // MARK: - Image Cache (NSCache — auto eviction)
    private let garmentImageCache = NSCache<NSString, UIImage>()
    var garmentImagesVersion: Int = 0 // SwiftUI re-render trigger
    private var failedImageIds: Set<String> = [] // Track failed downloads for retry
    nonisolated(unsafe) private var bulkLoadTask: Task<Void, Never>?
    private var memoryWarningObserver: (any NSObjectProtocol)?
    private var modelPhotoObserver: (any NSObjectProtocol)?

    // MARK: - Init

    init(
        garmentRepository: GarmentRepository,
        userRepository: UserRepository,
        storageRepository: StorageRepository,
        lookRepository: LookRepository,
        tryOnService: TryOnService = .shared,
        currentUserId: String
    ) {
        self.garmentRepository = garmentRepository
        self.userRepository = userRepository
        self.storageRepository = storageRepository
        self.lookRepository = lookRepository
        self.tryOnService = tryOnService
        self.currentUserId = currentUserId

        garmentImageCache.countLimit = 80
        garmentImageCache.totalCostLimit = 60 * 1024 * 1024 // 60MB

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.garmentImageCache.removeAllObjects()
            self?.garmentImagesVersion += 1
            #if DEBUG
            print("[ClosetVM] Memory warning — cache cleared")
            #endif
        }

        modelPhotoObserver = NotificationCenter.default.addObserver(
            forName: .modelPhotoDidUpdate,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshModelImage()
            }
        }
    }

    /// Reload model image from server (called when user changes it from Profile)
    func refreshModelImage() async {
        await loadModelImage()
    }

    nonisolated deinit {
        progressTask?.cancel()
        bulkLoadTask?.cancel()
    }

    // MARK: - Load Data

    func loadClosetData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadModelImage() }
            group.addTask { await self.loadGarments() }
        }
    }

    private func loadModelImage() async {
        isLoadingModelImage = true
        defer { isLoadingModelImage = false }

        do {
            let user = try await userRepository.getUser(id: currentUserId)
            guard let modelPath = user?.modelImagePath else {
                #if DEBUG
                print("[ClosetVM] No model image path found")
                #endif
                return
            }
            let data = try await storageRepository.downloadImage(path: modelPath)
            modelImage = UIImage(data: data)
        } catch {
            #if DEBUG
            print("[ClosetVM] Model image load failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func loadGarments() async {
        isLoadingGarments = true
        defer { isLoadingGarments = false }

        do {
            let result = try await garmentRepository.getGarmentsPaginated(
                userId: currentUserId,
                limit: pageSize,
                startAfter: nil
            )
            allGarments = result.garments
            lastDocument = result.lastDocument
            hasMoreGarments = result.garments.count >= pageSize
            // Start throttled image loading (max 3 concurrent)
            startThrottledImageLoading(force: true)
        } catch {
            #if DEBUG
            print("[ClosetVM] Garments load failed: \(error.localizedDescription)")
            #endif
            errorMessage = L10n.commonError
        }
    }

    func loadMoreGarments() async {
        guard hasMoreGarments, !isLoadingMore, !isLoadingGarments else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await garmentRepository.getGarmentsPaginated(
                userId: currentUserId,
                limit: pageSize,
                startAfter: lastDocument
            )
            allGarments.append(contentsOf: result.garments)
            lastDocument = result.lastDocument
            hasMoreGarments = result.garments.count >= pageSize
            startThrottledImageLoading(force: true)
        } catch {
            #if DEBUG
            print("[ClosetVM] Load more garments failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Garment Image Loading (Throttled)

    /// Start loading all garment images with concurrency limit
    private func startThrottledImageLoading(force: Bool = false) {
        if !force, let task = bulkLoadTask, !task.isCancelled {
            // A load is already in progress — don't interrupt
            return
        }
        bulkLoadTask?.cancel()

        let garmentsToLoad = allGarments.filter { garment in
            garmentImageCache.object(forKey: garment.id as NSString) == nil
        }
        guard !garmentsToLoad.isEmpty else {
            bulkLoadTask = nil
            return
        }

        bulkLoadTask = Task {
            await withTaskGroup(of: Void.self) { group in
                var inFlight = 0
                let maxConcurrent = 3

                for garment in garmentsToLoad {
                    guard !Task.isCancelled else { break }

                    if inFlight >= maxConcurrent {
                        await group.next()
                        inFlight -= 1
                    }

                    inFlight += 1
                    group.addTask {
                        await self.downloadAndCacheImage(for: garment)
                    }
                }
            }
            // Mark completed
            bulkLoadTask = nil
        }
    }

    /// Download a single garment image with retry (3 attempts, exponential backoff)
    private func downloadAndCacheImage(for garment: Garment) async {
        let key = garment.id as NSString

        // Skip if already cached
        if garmentImageCache.object(forKey: key) != nil { return }

        for attempt in 0..<3 {
            guard !Task.isCancelled else { return }
            do {
                let data = try await storageRepository.downloadImage(path: garment.imagePath)
                if let image = UIImage(data: data) {
                    garmentImageCache.setObject(image, forKey: key)
                    failedImageIds.remove(garment.id)
                    garmentImagesVersion += 1
                    return
                } else {
                    #if DEBUG
                    print("[ClosetVM] Downloaded data is not a valid image for \(garment.id) (attempt \(attempt + 1))")
                    #endif
                }
            } catch {
                #if DEBUG
                print("[ClosetVM] Image load failed for \(garment.id) (attempt \(attempt + 1)): \(error.localizedDescription)")
                #endif
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1)) * 1_000_000_000)
                }
            }
        }

        // All attempts failed — track for retry
        failedImageIds.insert(garment.id)
    }

    /// Retry loading any images that aren't cached yet (failed, cancelled, or never started)
    func retryFailedImages() {
        let uncached = allGarments.filter { garmentImageCache.object(forKey: $0.id as NSString) == nil }
        guard !uncached.isEmpty else { return }
        #if DEBUG
        print("[ClosetVM] Retrying \(uncached.count) uncached image(s)")
        #endif
        startThrottledImageLoading(force: true)
    }

    /// Force reload all uncached images (e.g. after network recovery)
    func forceReloadImages() {
        startThrottledImageLoading(force: true)
    }

    func garmentImage(for garmentId: String) -> UIImage? {
        garmentImageCache.object(forKey: garmentId as NSString)
    }

    // MARK: - Selection

    func selectGarment(_ garment: Garment, image: UIImage) {
        // Remove conflicting selections
        for conflictType in garment.type.conflictsWith {
            selectedGarments.removeValue(forKey: conflictType)
            selectedGarmentImages.removeValue(forKey: conflictType)
        }

        selectedGarments[garment.type] = garment
        selectedGarmentImages[garment.type] = image

        HapticManager.shared.light()
    }

    func deselectGarment(type: GarmentType) {
        selectedGarments.removeValue(forKey: type)
        selectedGarmentImages.removeValue(forKey: type)

        HapticManager.shared.light()
    }

    func isTypeDisabled(_ type: GarmentType) -> Bool {
        for (selectedType, _) in selectedGarments {
            if selectedType.conflictsWith.contains(type) {
                return true
            }
        }
        return false
    }

    func clearSelections() {
        selectedGarments.removeAll()
        selectedGarmentImages.removeAll()
        resultImage = nil
        errorMessage = nil
    }

    // MARK: - Try-On

    func performTryOn() async {
        guard hasClothingSelected, let modelImage = modelImage else { return }

        isProcessing = true
        progress = 0.0
        errorMessage = nil
        resultImage = nil
        currentStep = L10n.comboPreparing

        do {
            // Build garment tuples (sorted: bottom → top → dress → jacket → shoes)
            let garmentOrder: [GarmentType] = [.bottom, .top, .dress, .jacket, .shoes]
            let sorted = selectedGarmentImages.sorted { first, second in
                let fi = garmentOrder.firstIndex(of: first.key) ?? garmentOrder.count
                let si = garmentOrder.firstIndex(of: second.key) ?? garmentOrder.count
                return fi < si
            }
            let tuples = sorted.map { (type: $0.key, image: $0.value) }

            // Start simulated progress
            startSimulatedProgress()

            currentStep = L10n.comboApplyingGarments

            let rawResult = try await tryOnService.generateTryOn(
                personImage: modelImage,
                garmentImages: tuples
            )

            stopSimulatedProgress()

            currentStep = L10n.comboFinalizing
            progress = 0.92

            // Arka planı sadece AI-generated model fotoğraflarında sil
            resultImage = rawResult

            progress = 1.0
            currentStep = L10n.comboDone
            HapticManager.shared.success()

        } catch {
            stopSimulatedProgress()
            #if DEBUG
            print("[ClosetVM] Try-on failed: \(error.localizedDescription)")
            #endif

            if case TryOnError.insufficientCredits = error {
                errorMessage = L10n.tryonInsufficientCredits
            } else {
                errorMessage = L10n.comboFailed
            }
            HapticManager.shared.error()
        }

        isProcessing = false
    }

    // MARK: - Save Look

    func saveLookInBackground() -> Bool {
        guard let resultImage = resultImage else { return false }

        let capturedResultImage = resultImage
        let capturedUserId = currentUserId
        let capturedGarments = selectedGarments
        let storageRepo = storageRepository
        let lookRepo = lookRepository

        Task.detached(priority: .userInitiated) {
            let lookId = UUID().uuidString
            let resultImagePath = "users/\(capturedUserId)/looks/\(lookId).enc"

            do {
                try await storageRepo.uploadImage(image: capturedResultImage, path: resultImagePath)

                let garments = capturedGarments.values.map { $0 }
                let look = Look(
                    id: lookId,
                    resultImagePath: resultImagePath,
                    garments: Array(garments),
                    isCombo: capturedGarments.count > 1,
                    isFavorite: false,
                    source: .closet
                )

                try await lookRepo.saveLook(look, userId: capturedUserId)
                AnalyticsService.shared.logLookSaved(isCombo: capturedGarments.count > 1)

                await MainActor.run {
                    NotificationCenter.default.post(name: .lookSavedInBackground, object: nil)
                }

                #if DEBUG
                print("[ClosetVM] Look saved in background!")
                #endif
            } catch {
                #if DEBUG
                print("[ClosetVM] Background save failed: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    NotificationCenter.default.post(name: .lookSaveFailed, object: nil)
                }
            }
        }

        return true
    }

    // MARK: - Add New Garment

    @discardableResult
    func addNewGarment(image: UIImage, type: GarmentType, activeUserId: String? = nil) async -> Bool {
        isAddingGarment = true
        defer { isAddingGarment = false }

        let userId = activeUserId ?? currentUserId

        do {
            let garmentId = UUID().uuidString
            let garmentPath = "users/\(userId)/garments/\(garmentId).enc"

            try await storageRepository.uploadImage(image: image, path: garmentPath)

            let garment = Garment(
                id: garmentId,
                imagePath: garmentPath,
                type: type
            )

            try await garmentRepository.saveGarment(garment, userId: userId)

            // Update local state + cache
            allGarments.insert(garment, at: 0)
            garmentImageCache.setObject(image, forKey: garmentId as NSString)
            garmentImagesVersion += 1

            HapticManager.shared.success()

            #if DEBUG
            print("[ClosetVM] Garment added: \(type.displayName)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[ClosetVM] Add garment failed: \(error.localizedDescription)")
            #endif
            errorMessage = L10n.commonError
            HapticManager.shared.error()
            return false
        }
    }

    // MARK: - Delete Garment

    func deleteGarments(_ garments: [Garment]) async {
        for garment in garments {
            await deleteGarment(garment)
        }
    }

    func deleteGarment(_ garment: Garment) async {
        do {
            try await garmentRepository.deleteGarment(id: garment.id, userId: currentUserId)
            try? await storageRepository.deleteImage(path: garment.imagePath)

            allGarments.removeAll { $0.id == garment.id }
            garmentImageCache.removeObject(forKey: garment.id as NSString)
            garmentImagesVersion += 1

            // Deselect if selected
            if selectedGarments[garment.type]?.id == garment.id {
                deselectGarment(type: garment.type)
            }

            HapticManager.shared.light()
        } catch {
            #if DEBUG
            print("[ClosetVM] Delete garment failed: \(error.localizedDescription)")
            #endif
            errorMessage = L10n.commonError
        }
    }

    // MARK: - Simulated Progress

    private func startSimulatedProgress() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            guard let self else { return }
            let totalDuration: Double = 25
            let steps = 50
            let interval = totalDuration / Double(steps)

            for i in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.progress = min(Double(i) / Double(steps) * 0.90, 0.90)
            }
        }
    }

    private func stopSimulatedProgress() {
        progressTask?.cancel()
        progressTask = nil
    }
}
