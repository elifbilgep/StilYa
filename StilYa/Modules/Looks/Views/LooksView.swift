//
//  LooksView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI
import Photos

private enum LookTab: String, CaseIterable {
    case all
    case closet
}

struct LooksView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedLook: Look?
    @State private var isPro = RevenueCatManager.shared.isProActive
    @State private var showAccountLinking = false
    @State private var selectedTab: LookTab = .all

    private var viewModel: LooksViewModel? {
        container.looksViewModel
    }

    private var displayedLooks: [Look] {
        guard let viewModel = viewModel else { return [] }
        switch selectedTab {
        case .all:
            return viewModel.looks
        case .closet:
            return viewModel.closetLooks
        }
    }

    var body: some View {
        VStack(spacing: 0) {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(L10n.looksTitle)
                    .font(STFont.displayPage)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)

                // Custom Tab Picker
                HStack(spacing: 0) {
                    ForEach(LookTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(tab == .all ? L10n.looksTabAll : L10n.looksTabCloset)
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(selectedTab == tab ? .textPrimary : .textSecondary.opacity(0.5))
                                    .padding(.vertical, 6)

                                Rectangle()
                                    .fill(selectedTab == tab ? Color.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)

                Spacer().frame(height: 20)

                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.textSecondary)
                        Spacer()
                    } else if displayedLooks.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: selectedTab == .closet ? "cabinet" : "photo.stack")
                                .font(.system(size: 60))
                                .foregroundColor(.textSecondary.opacity(0.3))

                            Text(selectedTab == .closet ? L10n.looksEmptyCloset : L10n.looksEmpty)
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            // Reference version counters so SwiftUI re-renders when NSCache updates
                            let _ = viewModel.lookImagesVersion
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 16
                            ) {
                                ForEach(Array(displayedLooks.enumerated()), id: \.element.id) { index, look in
                                    LookPhotoCard(
                                        look: look,
                                        image: viewModel.lookImage(for: look.id),
                                        isImageFailed: viewModel.isLookImageFailed(look.id),
                                        garmentCount: look.garments.count,
                                        index: index,
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteLook(look)
                                            }
                                        }
                                    )
                                    .onAppear {
                                        // Lazy load: only download when card scrolls into view
                                        if viewModel.lookImage(for: look.id) == nil {
                                            Task {
                                                await viewModel.loadLookImage(look)
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        selectedLook = look
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.screenHorizontal)
                            .padding(.top, 8)

                            // Load More button
                            if viewModel.hasMoreLooks {
                                Button {
                                    Task {
                                        await viewModel.loadMoreLooks()
                                        // New cards lazy-load images via onAppear
                                    }
                                } label: {
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                            .tint(.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Spacing.md)
                                    } else {
                                        Text(L10n.commonLoadMore)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.bgSecondary)
                                            )
                                            .padding(.horizontal, Spacing.screenHorizontal)
                                    }
                                }
                                .disabled(viewModel.isLoadingMore)
                            }

                            Spacer().frame(height: 32)
                        }
                    }
                } else {
                    Spacer()
                    ProgressView()
                        .tint(.textSecondary)
                    Spacer()
                }
            }
        }

        } // VStack
        .sheet(item: $selectedLook) { look in
            if let viewModel = viewModel {
                LookDetailSheet(
                    look: look,
                    lookImageProvider: { viewModel.lookImageFullRes(for: look) },
                    garmentImageProvider: { viewModel.garmentImage(for: $0) },
                    onDelete: {
                        selectedLook = nil
                        Task {
                            await viewModel.deleteLook(look)
                        }
                    },
                    onAddToCart: { garment, garmentImage, link, brand, price in
                        if let authVM = container.authViewModel, !authVM.requireAccountLinking(context: .addToCart) {
                            showAccountLinking = true
                            return
                        }
                        await addGarmentToCart(garmentImage: garmentImage, garmentType: garment.type, link: link, brand: brand, price: price)
                    },
                    onAddToCloset: { garment, garmentImage in
                        if let authVM = container.authViewModel, !authVM.requireAccountLinking(context: .addToCloset) {
                            showAccountLinking = true
                            return false
                        }
                        guard let closetVM = container.closetViewModel else { return false }
                        return await closetVM.addNewGarment(image: garmentImage, type: garment.type)
                    },
                    lookImagesVersion: viewModel.lookImagesVersion,
                    garmentImagesVersion: viewModel.garmentImagesVersion
                )
                .task {
                    // Sheet açılınca look + garment görselleri yükle (cache'te yoksa indir)
                    async let loadLook: () = viewModel.loadLookImage(look)
                    async let loadGarments: () = viewModel.loadGarmentImages(for: look)
                    _ = await (loadLook, loadGarments)
                }
            }
        }
        .task {
            // Re-initialize if nil (e.g. after logout + re-login)
            if container.looksViewModel == nil {
                container.initializeLooksViewModel()
            }
            guard let viewModel = viewModel else { return }
            await viewModel.loadLooks()
            // Images are lazy-loaded per card via onAppear
        }
        .onReceive(NotificationCenter.default.publisher(for: .lookSavedInBackground)) { _ in
            Task {
                await viewModel?.loadLooks()
                // Images are lazy-loaded per card via onAppear
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App öne geldiğinde NSCache boşalmış olabilir — disk cache'ten yeniden yükle
                Task {
                    await viewModel?.reloadEvictedImages()
                }
            }
        }
        .onReceive(RevenueCatManager.shared.$isProActive) { newValue in
            isPro = newValue
        }
        .sheet(isPresented: $showAccountLinking) {
            if let authVM = container.authViewModel {
                AccountLinkingSheet(authViewModel: authVM)
                    .preferredColorScheme(.light)
            }
        }
    }

    // MARK: - Add Garment to Cart
    private func addGarmentToCart(garmentImage: UIImage, garmentType: GarmentType, link: String, brand: String?, price: Double?) async {
        guard let userId = container.authRepository.getCurrentUserId() else {
            #if DEBUG
            print("❌ [Looks] No user ID found")
            #endif
            return
        }

        do {
            let garmentId = UUID().uuidString
            let imagePath = "users/\(userId)/garments/\(garmentId).enc"

            try await container.storageRepository.uploadImage(
                image: garmentImage,
                path: imagePath
            )

            let garment = Garment(
                id: garmentId,
                imagePath: imagePath,
                type: garmentType,
                brand: brand,
                price: price,
                currency: "TRY",
                productLink: link,
                isInCart: true
            )

            try await container.garmentRepository.saveGarment(garment, userId: userId)

            #if DEBUG
            print("✅ [Looks] Garment added to cart successfully!")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Looks] Failed to add to cart: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Look Photo Card Component (Polaroid with Tape)
struct LookPhotoCard: View {
    let look: Look
    let image: UIImage?
    var isImageFailed: Bool = false
    let garmentCount: Int
    let index: Int
    let onDelete: () -> Void

    // Deterministic random values based on look id
    private var rotation: Double {
        let hash = abs(look.id.hashValue)
        let base = Double(hash % 7) - 3.0 // -3 to +3 range
        // Alternate sign based on index for variety
        return index % 2 == 0 ? base : -base
    }

    private var tapeRotation: Double {
        let hash = abs(look.id.hashValue >> 4)
        return Double(hash % 30) - 15.0 // -15 to +15 range
    }

    private var tapeOffset: CGFloat {
        let hash = abs(look.id.hashValue >> 8)
        return CGFloat(hash % 20) - 10.0 // -10 to +10 horizontal offset
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Main polaroid card
                VStack(spacing: 0) {
                    // Photo area
                    ZStack(alignment: .bottomTrailing) {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                        } else if isImageFailed {
                            Rectangle()
                                .fill(Color.bgSecondary)
                                .frame(height: 180)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                        .foregroundColor(.textSecondary.opacity(0.3))
                                )
                        } else {
                            Rectangle()
                                .fill(Color.bgSecondary)
                                .frame(height: 180)
                                .overlay(
                                    ProgressView()
                                        .tint(.textSecondary)
                                )
                        }

                        // Badges
                        HStack(spacing: 4) {
                            if look.isCombo {
                                Text(L10n.looksCombo)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accent))
                            }

                            if garmentCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "tshirt.fill")
                                        .font(.system(size: 8))
                                    Text("\(garmentCount)")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                            }
                        }
                        .padding(6)
                    }

                    // Polaroid white bottom
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 28)
                        .overlay(
                            Text(look.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                                .font(STFont.handwritingSmall)
                                .foregroundColor(.textSecondary.opacity(0.6))
                                .rotationEffect(.degrees(-1.5))
                        )
                }
                .padding(6)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 1, y: 3)

                // Tape overlay
                TapeView(rotation: tapeRotation)
                    .offset(x: tapeOffset, y: -8)
            }
        }
        .rotationEffect(.degrees(rotation))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.commonDelete, systemImage: "trash")
            }
        }
    }
}

// MARK: - Tape View
private struct TapeView: View {
    let rotation: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.7),
                        Color(red: 0.88, green: 0.84, blue: 0.72).opacity(0.55)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 48, height: 16)
            .overlay(
                // Subtle tape texture lines
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 0.5)
                    }
                }
            )
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Look Detail Sheet
struct LookDetailSheet: View {
    let look: Look
    let lookImageProvider: () -> UIImage?
    let garmentImageProvider: (String) -> UIImage?
    let onDelete: () -> Void
    let onAddToCart: (Garment, UIImage, String, String?, Double?) async -> Void
    let onAddToCloset: ((Garment, UIImage) async -> Bool)?
    /// NSCache güncellendiğinde re-render tetiklemek için version counters
    var lookImagesVersion: Int = 0
    var garmentImagesVersion: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var savedToGallery = false
    @State private var addToCartGarment: Garment?
    @State private var addedToCartIds: Set<String> = []
    @State private var addedToClosetIds: Set<String> = []
    @State private var showDeleteConfirmation = false

    private var lookImage: UIImage? { lookImageProvider() }

    var body: some View {
        // trigger re-render when images load
        let _ = lookImagesVersion
        let _ = garmentImagesVersion
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large result image
                        if let image = lookImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding(.horizontal, Spacing.screenHorizontal)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.bgSecondary)
                                .frame(height: 400)
                                .overlay(
                                    ProgressView()
                                        .tint(.textSecondary)
                                )
                                .padding(.horizontal, Spacing.screenHorizontal)
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            // Save to gallery
                            Button {
                                if let image = lookImage {
                                    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                        guard status == .authorized || status == .limited else {
                                            DispatchQueue.main.async {
                                                // İzin verilmedi — kullanıcıya bilgi ver
                                                savedToGallery = false
                                            }
                                            return
                                        }
                                        PHPhotoLibrary.shared().performChanges {
                                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                                        } completionHandler: { success, _ in
                                            DispatchQueue.main.async {
                                                if success {
                                                    savedToGallery = true
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                        savedToGallery = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: savedToGallery ? "checkmark.circle.fill" : "square.and.arrow.down")
                                        .font(.system(size: 14))
                                    Text(savedToGallery ? L10n.commonSaved : L10n.tryonSaveToGallery)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(savedToGallery ? .success : .textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.bgSecondary)
                                )
                            }

                            // Share
                            Button {
                                showShareSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14))
                                    Text(L10n.commonShare)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.bgSecondary)
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // Garments section
                        if !look.garments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(L10n.comboDetails)
                                    .font(STFont.displaySection)
                                    .foregroundColor(.textPrimary)

                                ForEach(look.garments) { garment in
                                    HStack(spacing: 12) {
                                        if let img = garmentImageProvider(garment.id) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 56, height: 56)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.border, lineWidth: 0.5)
                                                )
                                        } else {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.bgSecondary)
                                                .frame(width: 56, height: 56)
                                                .overlay(
                                                    Text(garment.type.shortLabel)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.textSecondary.opacity(0.5))
                                                )
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(garment.type.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.textPrimary)

                                            if let brand = garment.brand, !brand.isEmpty {
                                                Text(brand)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.textSecondary)
                                            }

                                            if let price = garment.priceFormatted {
                                                Text(price)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.accent)
                                            }
                                        }

                                        Spacer()

                                        if garmentImageProvider(garment.id) != nil {
                                            HStack(spacing: 12) {
                                                // Add to Closet
                                                if let onAddToCloset = onAddToCloset {
                                                    Button {
                                                        guard let img = garmentImageProvider(garment.id) else { return }
                                                        Task {
                                                            let success = await onAddToCloset(garment, img)
                                                            if success {
                                                                addedToClosetIds.insert(garment.id)
                                                            }
                                                        }
                                                    } label: {
                                                        Image(systemName: addedToClosetIds.contains(garment.id) ? "checkmark.circle.fill" : "cabinet.fill")
                                                            .font(.system(size: 18))
                                                            .foregroundColor(addedToClosetIds.contains(garment.id) ? .success : .accent)
                                                    }
                                                    .disabled(addedToClosetIds.contains(garment.id))
                                                }

                                                // Add to Cart
                                                Button {
                                                    addToCartGarment = garment
                                                } label: {
                                                    Image(systemName: addedToCartIds.contains(garment.id) ? "checkmark.circle.fill" : "cart.badge.plus")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(addedToCartIds.contains(garment.id) ? .success : .accent)
                                                }
                                                .disabled(addedToCartIds.contains(garment.id))
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.bgSecondary)
                                    )
                                }
                            }
                            .padding(.horizontal, Spacing.screenHorizontal)
                        }

                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                            Text(look.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.error)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = lookImage {
                ShareSheet(items: ShareableContent.look(image: image))
            }
        }
        .sheet(item: $addToCartGarment) { garment in
            if let garmentImage = garmentImageProvider(garment.id) {
                AddToCartSheet(
                    garmentImage: garmentImage,
                    onSave: { link, brand, price in
                        addedToCartIds.insert(garment.id)
                        Task {
                            await onAddToCart(garment, garmentImage, link, brand, price)
                        }
                    }
                )
                .preferredColorScheme(.light)
            }
        }
        .presentationDragIndicator(.visible)
        .alert(L10n.commonDelete, isPresented: $showDeleteConfirmation) {
            Button(L10n.commonCancel, role: .cancel) { }
            Button(L10n.commonDelete, role: .destructive) {
                onDelete()
            }
        } message: {
            Text(L10n.looksDeleteConfirmation)
        }
    }
}
