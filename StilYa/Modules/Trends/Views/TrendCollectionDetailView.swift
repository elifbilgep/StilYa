//
//  TrendCollectionDetailView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//

import SwiftUI

struct TrendCollectionDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let collection: TrendCollection
    @ObservedObject var viewModel: TrendsViewModel

    @State private var isDownloading = false
    @State private var isProcessing = false
    @State private var resultImage: UIImage?
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showComboFlow = false
    @State private var comboOutfitImage: UIImage?
    @State private var outfitReferenceImage: UIImage?
    @State private var showProView = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 20) {
                        if !collection.tags.isEmpty {
                            tagsRow
                        }
                        outfitList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }

            // Processing overlay
            if isDownloading || isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                            Text(isProcessing ? L10n.tryonProcessingGeneratingImage : L10n.trendsDownloading)
                                .font(.custom("DMSans-Medium", size: 15))
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color.accent.opacity(0.9))
                        .cornerRadius(20)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                isDownloading = false
                                isProcessing = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 28, height: 28)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .offset(x: 6, y: -6)
                        }
                    )
            }
        }
        .sheet(isPresented: $showResult) {
            if let result = resultImage {
                TrendResultSheet(
                    resultImage: result,
                    referenceImage: outfitReferenceImage,
                    onSave: { saveToLooks(result) },
                    onSaveToGallery: {
                        UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil)
                        HapticManager.shared.success()
                    },
                    onShare: {},
                    onClose: { showResult = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert(L10n.commonError, isPresented: $showError) {
            Button(L10n.commonOk) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showProView) {
            ProView()
                .environmentObject(container)
                .environmentObject(localizationManager)
        }
        .fullScreenCover(isPresented: $showComboFlow) {
            if let img = comboOutfitImage {
                DressUpFlowView(trendOutfitImage: img)
                    .environmentObject(container)
                    .environmentObject(router)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accent)
                    .frame(width: 36, height: 36)
                    .background(Color.bgSecondary)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(collection.localizedTitle.isEmpty ? localizedCategory(collection.category) : collection.localizedTitle)
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.accent)

                Text("\(collection.imageUrls.count) \(L10n.trendsCollections)")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(.accent.opacity(0.5))
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Tags

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(collection.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.accent.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.bgSecondary)
                        .cornerRadius(14)
                }
            }
        }
    }

    // MARK: - Outfit List

    private var outfitList: some View {
        LazyVStack(spacing: 24) {
            ForEach(collection.imageUrls, id: \.self) { url in
                outfitCard(url: url)
            }
        }
    }

    private func outfitCard(url: String) -> some View {
        let isFav = viewModel.isFavorite(url)

        return VStack(spacing: 0) {
            // Image (not tappable, height capped)
            ZStack(alignment: .topTrailing) {
                RetryImageView(url: url)
                    .aspectRatio(3/4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Favorite badge
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.toggleFavorite(url)
                    }
                }) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(isFav ? Color.error.opacity(0.85) : Color.black.opacity(0.35))
                        .clipShape(Circle())
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Action buttons
            HStack(spacing: 8) {
                // Kombin Yap
                Button(action: {
                    Task { await openComboFlow(url: url) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "scissors")
                            .font(.system(size: 13))
                        Text(L10n.trendsMakeCombo)
                            .font(.custom("DMSans-SemiBold", size: 13))
                    }
                    .foregroundColor(.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.bgSecondary)
                    .cornerRadius(12)
                }

                // Try On
                Button(action: {
                    if RevenueCatManager.shared.isProActive {
                        Task { await performOutfitTryOn(url: url) }
                    } else {
                        showProView = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "tshirt.fill")
                            .font(.system(size: 13))
                        Text(L10n.trendsTryOn)
                            .font(.custom("DMSans-SemiBold", size: 13))
                        if !RevenueCatManager.shared.isProActive {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.proGold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accent)
                    .cornerRadius(12)
                }
            }
            .padding(.top, 10)
        }
    }


    // MARK: - Open Combo Flow

    private func openComboFlow(url: String) async {
        isDownloading = true
        guard let image = await viewModel.downloadImage(from: url) else {
            isDownloading = false
            errorMessage = L10n.trendsImageLoadError
            showError = true
            return
        }
        isDownloading = false
        comboOutfitImage = image
        showComboFlow = true
    }

    // MARK: - Outfit Try-On (Direct AI Call)

    private func performOutfitTryOn(url: String) async {
        guard let userId = container.authRepository.getCurrentUserId() else { return }

        isDownloading = true
        guard let outfitImage = await viewModel.downloadImage(from: url) else {
            isDownloading = false
            errorMessage = "Görsel yüklenemedi"
            showError = true
            return
        }
        isDownloading = false

        isProcessing = true
        do {
            guard let user = try await container.userRepository.getUser(id: userId),
                  let modelImagePath = user.modelImagePath else {
                isProcessing = false
                errorMessage = L10n.tryonModelNotFound
                showError = true
                return
            }

            let modelImage = try await container.userRepository.getModelImage(
                userId: userId,
                path: modelImagePath
            )

            let result = try await container.tryOnService.tryOnOutfit(
                personImage: modelImage,
                outfitImage: outfitImage
            )

            // No background removal for outfit results — Vision removes bags/accessories
            resultImage = capImageHeight(result, maxHeight: 1200)
            outfitReferenceImage = outfitImage

            isProcessing = false
            showResult = true

        } catch {
            isProcessing = false
            if let tryOnErr = error as? TryOnError {
                errorMessage = tryOnErr.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
    }

    // MARK: - Save to Looks

    private func saveToLooks(_ image: UIImage) {
        guard let userId = container.authRepository.getCurrentUserId() else { return }

        let capturedImage = image
        let storageRepo = container.storageRepository
        let lookRepo = container.lookRepository

        Task.detached(priority: .userInitiated) {
            let lookId = UUID().uuidString
            do {
                let resultImagePath = try await storageRepo.uploadLookImage(
                    capturedImage, lookId: lookId, userId: userId
                )
                let look = Look(
                    id: lookId,
                    resultImagePath: resultImagePath,
                    garments: [],
                    isCombo: false,
                    isFavorite: false,
                    source: .tryOn
                )
                try await lookRepo.saveLook(look, userId: userId)

                await MainActor.run {
                    NotificationCenter.default.post(name: .lookSavedInBackground, object: nil)
                }
            } catch {
                #if DEBUG
                print("[TrendDetail] Save look failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Image Helpers

    private func capImageHeight(_ image: UIImage, maxHeight: CGFloat) -> UIImage {
        guard image.size.height > maxHeight else { return image }
        let scale = maxHeight / image.size.height
        let newSize = CGSize(width: image.size.width * scale, height: maxHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func localizedCategory(_ cat: String) -> String {
        switch cat {
        case "casual": return L10n.trendsCategoryCasual
        case "elegant": return L10n.trendsCategoryElegant
        case "streetwear": return L10n.trendsCategoryStreetwear
        case "sporty": return L10n.trendsCategorySporty
        case "bohemian": return L10n.trendsCategoryBohemian
        case "minimal": return L10n.trendsCategoryMinimal
        default: return cat.capitalized
        }
    }
}

