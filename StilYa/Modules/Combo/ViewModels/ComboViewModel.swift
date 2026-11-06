//
//  ComboViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 27.12.2025.
//  Updated: 2026-02-15 - Removed accessories from combo flow
//

import Foundation
import SwiftUI

// MARK: - Combo Phase (hangi aşamadayız?)
enum ComboPhase: Equatable {
    case idle
    case preparingImages                                          // Görseller hazırlanıyor
    case analyzingGarments(name: String)                          // Kıyafetler analiz ediliyor
    case applyingGarments(name: String, index: Int, total: Int)   // Kıyafetler giyiliyor
    case finalizing                                               // Son dokunuşlar
    case done
}

@Observable
final class ComboViewModel {
    // MARK: - Properties
    private let tryOnService: TryOnService                 // fal (via worker) — virtual try-on
    private let userRepository: UserRepository
    private let storageRepository: StorageRepository
    private let lookRepository: LookRepository
    private let currentUserId: String

    var isProcessing = false
    var progress: Double = 0.0
    var resultImage: UIImage?
    var errorMessage: String?
    var currentStep: String = ""
    var comboPhase: ComboPhase = .idle
    var processingStartTime: Date?
    private var comboTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    // Selected items
    var selectedGarments: [GarmentType: UIImage] = [:]      // Main garments (top, bottom, dress)
    var garmentProductDetails: [GarmentType: (brand: String?, price: Double?, productLink: String?)] = [:]

    // MARK: - Initialization
    init(
        tryOnService: TryOnService = .shared,
        userRepository: UserRepository,
        storageRepository: StorageRepository,
        lookRepository: LookRepository,
        currentUserId: String
    ) {
        self.tryOnService = tryOnService
        self.userRepository = userRepository
        self.storageRepository = storageRepository
        self.lookRepository = lookRepository
        self.currentUserId = currentUserId
    }

    deinit {
        comboTask?.cancel()
        progressTask?.cancel()
    }

    // MARK: - Full Combo Try-On (Single API Call — Identity Preserved)

    /// Creates a complete outfit in a SINGLE fal image-edit call.
    /// Credits deducted server-side via Worker.
    @MainActor
    func performComboTryOn(
        modelImage: UIImage,
        selectedGarments: [GarmentType: UIImage]
    ) async {
        // Önceki işlemi iptal et
        comboTask?.cancel()

        isProcessing = true
        progress = 0.0
        errorMessage = nil
        resultImage = nil
        currentStep = L10n.comboPreparing
        comboPhase = .idle

        do {
            guard !selectedGarments.isEmpty else {
                throw NSError(domain: "ComboViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: L10n.comboNoItemSelected])
            }

            AnalyticsService.shared.logComboStarted(garmentCount: selectedGarments.count, accessoryCount: 0)
            processingStartTime = Date()

            #if DEBUG
            print("👗 [ComboVM] Starting combo try-on via fal (identity preserved)")
            print("   - Garments: \(selectedGarments.count) (\(selectedGarments.keys.map { $0.displayName }.joined(separator: ", ")))")
            #endif

            // Kıyafetleri sırala (bottom → top → dress → jacket → shoes)
            // Jacket en son çünkü dış katman — üstüne giyilir
            let garmentOrder: [GarmentType] = [.bottom, .top, .dress, .jacket, .shoes]
            let sortedGarments = selectedGarments.sorted { first, second in
                let firstIndex = garmentOrder.firstIndex(of: first.key) ?? garmentOrder.count
                let secondIndex = garmentOrder.firstIndex(of: second.key) ?? garmentOrder.count
                return firstIndex < secondIndex
            }
            let garmentNames = sortedGarments.map { $0.key.displayName }
            let allNames = garmentNames.joined(separator: ", ")

            // Tuple'ları hazırla
            let garmentTuples = sortedGarments.map { (type: $0.key, image: $0.value) }

            // API call — mask pipeline or legacy
            let totalVisualSteps = max(garmentTuples.count, 1)
            progress = 0.05

            comboPhase = .applyingGarments(name: allNames, index: 1, total: totalVisualSteps)
            currentStep = L10n.comboApplyingGarments

            #if DEBUG
            print("👗 [ComboVM] Applying \(garmentTuples.count) garments in SINGLE call...")
            #endif

            let capturedAllNames = allNames
            startSimulatedProgress(from: 0.05, to: 0.90) { fraction in
                let currentIndex = min(Int(fraction * Double(totalVisualSteps)) + 1, totalVisualSteps)
                return .applyingGarments(name: capturedAllNames, index: currentIndex, total: totalVisualSteps)
            }

            let rawResult = try await tryOnService.generateTryOn(
                personImage: modelImage,
                garmentImages: garmentTuples
            )

            stopSimulatedProgress()

            comboPhase = .finalizing
            currentStep = L10n.comboFinalizing
            progress = 0.92

            // Sonuç doğrudan kullanılıyor (arka plan silme kapatıldı)
            resultImage = rawResult

            #if DEBUG
            print("✅ [ComboVM] Combo try-on completed!")
            #endif

            // DONE
            progress = 1.0
            currentStep = L10n.comboDone
            comboPhase = .done

            if let startTime = processingStartTime {
                let duration = Date().timeIntervalSince(startTime)
                AnalyticsService.shared.logComboCompleted(garmentCount: selectedGarments.count, accessoryCount: 0, duration: duration)
            }

        } catch is CancellationError {
            stopSimulatedProgress()
            #if DEBUG
            print("⚠️ [ComboVM] Combo try-on cancelled by user")
            #endif
            errorMessage = nil
        } catch {
            stopSimulatedProgress()
            AnalyticsService.shared.logComboFailed(error: error.localizedDescription)
            #if DEBUG
            print("❌ [ComboVM] Combo try-on failed: \(error.localizedDescription)")
            #endif
            if let aiError = error as? TryOnError, case .insufficientCredits = aiError {
                errorMessage = L10n.tryonInsufficientCredits
            } else {
                errorMessage = L10n.comboFailed
            }
        }

        isProcessing = false
    }

    /// İşlemi iptal et
    @MainActor
    func cancelComboTryOn() {
        comboTask?.cancel()
        progressTask?.cancel()
        isProcessing = false
        progress = 0.0
        currentStep = ""
        resultImage = nil
        #if DEBUG
        print("🛑 [ComboVM] Combo try-on cancelled")
        #endif
    }

    // MARK: - Simulated Progress

    /// API beklerken progress + phase'i kademeli günceller
    /// phaseUpdater: progress yüzdesine göre phase'i günceller (ör. "Kıyafet 1/4" → "2/4" → "3/4")
    @MainActor
    private func startSimulatedProgress(
        from start: Double,
        to end: Double,
        phaseUpdater: ((Double) -> ComboPhase)? = nil
    ) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            guard let self else { return }
            let totalDuration: Double = 25
            let steps = 50                  // 50 kademeli artış
            let interval = totalDuration / Double(steps)
            let increment = (end - start) / Double(steps)

            for i in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let newProgress = start + increment * Double(i)
                self.progress = min(newProgress, end)

                // Phase'i de güncelle (index ilerlesin)
                if let updater = phaseUpdater {
                    let fraction = Double(i) / Double(steps)
                    self.comboPhase = updater(fraction)
                }
            }
        }
    }

    @MainActor
    private func stopSimulatedProgress() {
        progressTask?.cancel()
        progressTask = nil
    }

    // MARK: - Clear All

    @MainActor
    func clearAll() {
        selectedGarments.removeAll()
        garmentProductDetails.removeAll()
        resultImage = nil
        errorMessage = nil
        #if DEBUG
        print("🗑️ [ComboVM] Cleared all selections")
        #endif
    }

    // MARK: - Save Combo Look

    /// Save look in background (view dismiss'e dayanıklı)
    /// Tüm değerleri capture edip detached task olarak çalıştırır
    @MainActor
    func saveComboLookInBackground(isCombo: Bool = true) -> Bool {
        guard let resultImage = resultImage else {
            return false
        }

        // Capture all values before detaching
        let capturedResultImage = resultImage
        let capturedUserId = currentUserId
        let capturedGarments = selectedGarments
        let capturedProductDetails = garmentProductDetails
        let storageRepo = storageRepository
        let lookRepo = lookRepository

        Task.detached(priority: .userInitiated) {
            #if DEBUG
            print("💾 [ComboVM] Background save started...")
            #endif
            let startTime = Date()

            let lookId = UUID().uuidString
            let resultImagePath = "users/\(capturedUserId)/looks/\(lookId).enc"

            do {
                // 1. Result image upload (bunu ilk yap — başarısız olursa look kaydetmenin anlamı yok)
                try await storageRepo.uploadImage(image: capturedResultImage, path: resultImagePath)

                // 2. Garment upload'ları paralel — her biri bağımsız, biri fail olursa diğerleri etkilenmesin
                let garments = await withTaskGroup(of: Garment?.self) { group in
                    for (type, image) in capturedGarments {
                        let garmentId = UUID().uuidString
                        let garmentPath = "users/\(capturedUserId)/garments/\(garmentId).enc"

                        group.addTask {
                            do {
                                try await storageRepo.uploadImage(image: image, path: garmentPath)
                                let details = capturedProductDetails[type]
                                return Garment(
                                    id: garmentId,
                                    imagePath: garmentPath,
                                    type: type,
                                    brand: details?.brand,
                                    price: details?.price,
                                    productLink: details?.productLink,
                                    isInCart: false
                                )
                            } catch {
                                #if DEBUG
                                print("⚠️ [ComboVM] Garment upload failed for \(type.displayName): \(error.localizedDescription)")
                                #endif
                                return nil
                            }
                        }
                    }

                    var uploadedGarments: [Garment] = []
                    for await garment in group {
                        if let garment = garment {
                            uploadedGarments.append(garment)
                        }
                    }
                    return uploadedGarments
                }

                let look = Look(
                    id: lookId,
                    resultImagePath: resultImagePath,
                    garments: garments,
                    isCombo: isCombo,
                    isFavorite: false,
                    source: .tryOn
                )

                try await lookRepo.saveLook(look, userId: capturedUserId)
                AnalyticsService.shared.logLookSaved(isCombo: isCombo)

                // Notify HomeView that a new look was saved
                await MainActor.run {
                    NotificationCenter.default.post(name: .lookSavedInBackground, object: nil)
                }

                let duration = Date().timeIntervalSince(startTime)
                #if DEBUG
                print("✅ [ComboVM] Combo saved in background (\(garments.count)/\(capturedGarments.count) garments) in \(String(format: "%.1f", duration))s!")
                #endif
            } catch {
                #if DEBUG
                print("❌ [ComboVM] Background save failed: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    NotificationCenter.default.post(name: .lookSaveFailed, object: nil)
                }
            }
        }

        return true
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let lookSavedInBackground = Notification.Name("lookSavedInBackground")
    static let lookSaveFailed = Notification.Name("lookSaveFailed")
}
