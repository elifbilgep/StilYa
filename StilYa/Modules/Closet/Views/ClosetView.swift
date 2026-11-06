//
//  ClosetView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//  Dress-up game style closet page — swipeable canvas
//

import SwiftUI

// MARK: - View Mode

private enum ClosetViewMode {
    case modelFocus   // Sadece model + seçim kutuları
    case split        // Varsayılan: model + raflar yan yana
    case shelvesFocus // Tam sayfa raflar
}

struct ClosetView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var localizationManager: LocalizationManager

    let shelfVisible: [Bool]
    let onClose: () -> Void

    @State private var viewModel: ClosetViewModel?
    @State private var closetColorScheme: ClosetColorScheme = .darkWoodScheme
    @State private var showResultSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCreditSheet = false
    @State private var garmentToDelete: Garment?
    @State private var toast: Toast?
    @State private var showAddGarmentSheet = false

    // Pro gating
    private var isPro: Bool { RevenueCatManager.shared.isProActive }
    @State private var showPaywall = false

    // Delete mode
    @State private var isDeleteMode = false
    @State private var selectedForDeletion: Set<String> = []

    // View mode & drag
    @State private var viewMode: ClosetViewMode = .split
    @State private var dragOffset: CGFloat = 0

    // Swipe hint
    @State private var showSwipeHint = false
    @AppStorage("closet_swipe_hint_shown") private var swipeHintShown = false

    // Category detail ("See All")
    @State private var selectedCategory: ShelfCategory?

    // Track version for NSCache re-render
    private var cacheVersion: Int {
        viewModel?.garmentImagesVersion ?? 0
    }

    // Shelf categories
    private enum ShelfCategory: Hashable {
        case topsJackets, bottoms, dresses, shoes
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)

                // Full-screen processing overlay
                if vm.isProcessing {
                    TryOnProcessingView(progress: vm.progress)
                        .transition(.opacity)
                        .zIndex(200)
                }
            } else {
                ProgressView()
            }

            // Category detail overlay
            if let category = selectedCategory, let vm = viewModel {
                let garments: [Garment] = {
                    switch category {
                    case .topsJackets: return vm.topAndJacketGarments
                    case .bottoms: return vm.bottomGarments
                    case .dresses: return vm.dressGarments
                    case .shoes: return vm.shoeGarments
                    }
                }()
                let title: String = {
                    switch category {
                    case .topsJackets: return L10n.closetShelfTopsJackets
                    case .bottoms: return L10n.closetShelfBottoms
                    case .dresses: return L10n.closetShelfDresses
                    case .shoes: return L10n.closetShelfShoes
                    }
                }()
                CategoryDetailView(
                    title: title,
                    garments: garments,
                    vm: vm,
                    cacheVersion: cacheVersion,
                    colorScheme: closetColorScheme,
                    onBack: { selectedCategory = nil },
                    onDelete: { garment in
                        garmentToDelete = garment
                        showDeleteConfirmation = true
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(50)
            }

            // Toast overlay
            if let toast {
                VStack {
                    Spacer()
                    ToastView(toast: toast)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedCategory)
        .onAppear {
            setupViewModel()
            // Retry any images that failed to load previously
            viewModel?.retryFailedImages()
        }
        .sheet(isPresented: $showAddGarmentSheet) {
            ClosetAddGarmentSheet(
                onAdd: { image, type in
                    showAddGarmentSheet = false
                    showToast(.success, L10n.closetAddedToCloset)
                    if let vm = viewModel {
                        Task {
                            await vm.addNewGarment(image: image, type: type)
                        }
                    }
                },
                onCancel: {
                    showAddGarmentSheet = false
                }
            )
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showCreditSheet) {
            HomeCreditSheet()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showPaywall) {
            ProView()
                .preferredColorScheme(.light)
        }
        .onChange(of: showResultSheet) { _, isShowing in
            if !isShowing {
                // Force-reload images that may have been evicted from cache during AI processing
                viewModel?.retryFailedImages()
            }
        }
        .fullScreenCover(isPresented: $showResultSheet) {
            if let vm = viewModel, let result = vm.resultImage {
                ComboResultView(
                    resultImage: .constant(result),
                    selectedGarments: vm.selectedGarmentImages,
                    isCombo: vm.selectedGarmentImages.count > 1,
                    hideClosetButton: true,
                    onSaveToProfile: {
                        let success = vm.saveLookInBackground()
                        if success {
                            showToast(.success, L10n.commonSaved)
                        }
                        return success
                    },
                    onSaveToGallery: {
                        UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil)
                        showToast(.success, L10n.tryonGallerySaved)
                    },
                    onShare: {
                        ShareHelper.share(items: ShareableContent.tryOnResult(image: result))
                    },
                    onAddToCart: { type, img, link, brand, price in
                        Task {
                            guard let userId = appContainer.authRepository.getCurrentUserId() else { return }
                            do {
                                let garmentId = UUID().uuidString
                                let imagePath = "users/\(userId)/garments/\(garmentId).enc"
                                try await appContainer.storageRepository.uploadImage(image: img, path: imagePath)
                                let garment = Garment(
                                    id: garmentId,
                                    imagePath: imagePath,
                                    type: type,
                                    brand: brand,
                                    price: price,
                                    currency: "TRY",
                                    productLink: link,
                                    isInCart: true
                                )
                                try await appContainer.garmentRepository.saveGarment(garment, userId: userId)
                                showToast(.success, L10n.comboAddedToCart(type.displayName))
                            } catch {
                                showToast(.error, L10n.comboCartAddFailed)
                            }
                        }
                    },
                    onAddToCloset: { _, _ in false },
                    onClose: {
                        showResultSheet = false
                    }
                )
                .preferredColorScheme(.light)
            }
        }
        .alert(L10n.commonDelete, isPresented: $showDeleteConfirmation) {
            Button(L10n.commonDelete, role: .destructive) {
                if let garment = garmentToDelete, let vm = viewModel {
                    Task { await vm.deleteGarment(garment) }
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.looksDeleteConfirmation)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: ClosetViewModel) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerBar(vm: vm)

                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let height = geometry.size.height

                    // Compute widths based on view mode
                    let modelRatio: CGFloat = {
                        switch viewMode {
                        case .modelFocus: return 1.0
                        case .split: return 0.48
                        case .shelvesFocus: return 0.0
                        }
                    }()
                    let modelWidth = totalWidth * modelRatio
                    let shelvesWidth = totalWidth - modelWidth

                    HStack(spacing: 0) {
                        // LEFT: Model + selection boxes
                        modelPanel(vm: vm, width: max(modelWidth, 0), height: height)
                            .frame(width: max(modelWidth, 0))
                            .opacity(modelWidth > 30 ? 1 : 0)
                            .clipped()

                        // RIGHT: Shelves
                        shelvesPanel(vm: vm, isFullWidth: viewMode == .shelvesFocus)
                            .frame(width: max(shelvesWidth, 0))
                            .opacity(shelvesWidth > 30 ? 1 : 0)
                            .clipped()
                    }
                    .offset(x: dragOffset * 0.3)
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 60
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    if value.translation.width < -threshold {
                                        // Sola kaydırdı → rafları genişlet
                                        switch viewMode {
                                        case .modelFocus: viewMode = .split
                                        case .split: viewMode = .shelvesFocus
                                        case .shelvesFocus: break
                                        }
                                    } else if value.translation.width > threshold {
                                        // Sağa kaydırdı → modeli genişlet
                                        switch viewMode {
                                        case .shelvesFocus: viewMode = .split
                                        case .split: viewMode = .modelFocus
                                        case .modelFocus: break
                                        }
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewMode)
                }

            }

            // Floating Dress Me button
            if vm.hasClothingSelected && viewMode != .shelvesFocus && !isDeleteMode {
                VStack(spacing: 8) {
                    Spacer()
                    floatingDressMeButton(vm: vm)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Delete mode banner
            if isDeleteMode {
                VStack {
                    Spacer()
                    deleteBanner(vm: vm)
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(15)
            }

            // Swipe hint banner
            if showSwipeHint {
                VStack {
                    Spacer()
                    SwipeHintBanner {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSwipeHint = false
                            swipeHintShown = true
                        }
                    }
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(10)
            }

            // Sliding view mode toggle
            VStack {
                Spacer()
                ClosetModeToggle(viewMode: $viewMode)
                    .padding(.bottom, vm.hasClothingSelected && viewMode != .shelvesFocus ? 78 : 28)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.hasClothingSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDeleteMode)
        .onAppear {
            if !swipeHintShown {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        showSwipeHint = true
                    }
                }
            }
        }
        .onChange(of: viewMode) { _, _ in
            // User swiped — dismiss hint
            if showSwipeHint {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSwipeHint = false
                    swipeHintShown = true
                }
            }
        }
    }

    // MARK: - Header

    private func headerBar(vm: ClosetViewModel) -> some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.bgSecondary)
                    .clipShape(Circle())
            }

            Spacer()

            Text(L10n.closetTitle)
                .font(STFont.displaySmall)
                .foregroundColor(.textPrimary)

            Spacer()

            // Delete mode button
            Button {
                guard isPro else { showPaywall = true; return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isDeleteMode.toggle()
                    if !isDeleteMode {
                        selectedForDeletion.removeAll()
                    }
                }
            } label: {
                Image(systemName: isDeleteMode ? "xmark" : "trash")
                    .font(.system(size: isDeleteMode ? 14 : 15, weight: .medium))
                    .foregroundColor(isDeleteMode ? .white : .textPrimary)
                    .frame(width: 36, height: 36)
                    .background(isDeleteMode ? Color.error : Color.bgSecondary)
                    .clipShape(Circle())
            }

            // Add product button
            Button {
                if isPro { showAddGarmentSheet = true } else { showPaywall = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.bgSecondary)
                    .clipShape(Circle())
            }
            .opacity(isDeleteMode ? 0.3 : 1)
            .disabled(isDeleteMode)
        }
        .padding(.horizontal, 16)
        .padding(.top, 68)
        .padding(.bottom, 8)
    }

    // MARK: - Model Panel

    private func modelPanel(vm: ClosetViewModel, width: CGFloat, height: CGFloat) -> some View {
        let isFullScreen = viewMode == .modelFocus

        return ZStack {
            if vm.isLoadingModelImage {
                VStack {
                    ProgressView()
                    Text(L10n.commonLoading)
                        .font(STFont.caption)
                        .foregroundColor(.textSecondary)
                }
            } else if let modelImg = vm.modelImage {
                Image(uiImage: modelImg)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: isFullScreen ? width * 0.7 : width * 0.95,
                        height: isFullScreen ? height * 0.88 : height * 0.7
                    )
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.textSecondary.opacity(0.3))
                    Text(L10n.closetNoModelPhoto)
                        .font(STFont.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }

            // Selection boxes — overlaid on the person image
            let imgWidth = isFullScreen ? width * 0.7 : width * 0.95
            let imgHeight = isFullScreen ? height * 0.88 : height * 0.7
            let offsetX = (width - imgWidth) / 2
            let offsetY = (height - imgHeight) / 2
            let leftX: CGFloat = isFullScreen ? 0.14 : 0.22
            let rightX: CGFloat = isFullScreen ? 0.88 : 0.82

            // Top — upper chest area
            liquidGlassBox(type: .top, vm: vm, size: CGSize(width: 58, height: 70))
                .position(
                    x: offsetX + imgWidth * leftX,
                    y: offsetY + imgHeight * 0.28
                )

            // Bottom — hip/thigh area
            liquidGlassBox(type: .bottom, vm: vm, size: CGSize(width: 58, height: 70))
                .position(
                    x: offsetX + imgWidth * leftX,
                    y: offsetY + imgHeight * 0.55
                )

            // Jacket — right side, upper chest
            liquidGlassBox(type: .jacket, vm: vm, size: CGSize(width: 58, height: 70))
                .position(
                    x: offsetX + imgWidth * rightX,
                    y: offsetY + imgHeight * 0.28
                )

            // Dress — right side of torso
            liquidGlassBox(type: .dress, vm: vm, size: CGSize(width: 62, height: 78))
                .position(
                    x: offsetX + imgWidth * rightX,
                    y: offsetY + imgHeight * 0.52
                )

            // Shoes — lower area
            liquidGlassBox(type: .shoes, vm: vm, size: CGSize(width: 52, height: 64))
                .position(
                    x: offsetX + imgWidth * rightX,
                    y: offsetY + imgHeight * 0.80
                )
        }
    }

    // MARK: - Liquid Glass Selection Box

    private func liquidGlassBox(type: GarmentType, vm: ClosetViewModel, size: CGSize) -> some View {
        let isDisabled = vm.isTypeDisabled(type)
        let isSelected = vm.selectedGarments[type] != nil
        let _ = cacheVersion

        return Group {
            if isSelected, let garment = vm.selectedGarments[type],
               let image = vm.garmentImage(for: garment.id) ?? vm.selectedGarmentImages[type] {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)

                    Button {
                        vm.deselectGarment(type: type)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .shadow(radius: 2)
                    }
                    .offset(x: 4, y: -4)
                }
            } else {
                Button {
                    guard isPro else { showPaywall = true; return }
                    if !isDisabled {
                        selectedCategory = shelfCategory(for: type)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(type.shortLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(isDisabled ? 0.3 : 0.85))
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(isDisabled ? 0.3 : 0.7))
                    }
                    .frame(width: size.width, height: size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isDisabled ? 0.08 : 0.35),
                                        .white.opacity(isDisabled ? 0.03 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                .disabled(isDisabled)
            }
        }
        .opacity(isDisabled ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // selectionBox replaced by liquidGlassBox above

    // MARK: - Shelves Panel

    private func shelvesPanel(vm: ClosetViewModel, isFullWidth: Bool) -> some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            // 4 shelves: each shelf = thumbHeight + 6 (frame) + 11 (wooden shelf) + ~20 (title+spacing)
            // Total overhead per shelf ≈ 37pt, 4 shelves = 148pt + spacers
            let shelfOverhead: CGFloat = 37
            let usableHeight = max(availableHeight - shelfOverhead * 4, 120)
            let rawThumbH = usableHeight / 4
            // Clamp: min 60, max 104 (full) / 88 (split)
            let maxH: CGFloat = isFullWidth ? 104 : 88
            let thumbHeight = min(max(rawThumbH, 60), maxH)
            let thumbSize = thumbHeight * (isFullWidth ? 80.0 / 104.0 : 68.0 / 88.0)

            VStack(spacing: 0) {
                Spacer(minLength: 0).frame(maxHeight: 12)

                shelfRow(
                    title: L10n.closetShelfTopsJackets,
                    garments: vm.topAndJacketGarments,
                    category: .topsJackets,
                    disabled: vm.isTypeDisabled(.top) && vm.isTypeDisabled(.jacket),
                    vm: vm,
                    isFullWidth: isFullWidth,
                    showSeeAll: isFullWidth,
                    visible: shelfVisible.indices.contains(0) ? shelfVisible[0] : false,
                    thumbSize: thumbSize,
                    thumbHeight: thumbHeight
                )

                Spacer(minLength: 0)

                shelfRow(
                    title: L10n.closetShelfBottoms,
                    garments: vm.bottomGarments,
                    category: .bottoms,
                    disabled: vm.isTypeDisabled(.bottom),
                    vm: vm,
                    isFullWidth: isFullWidth,
                    showSeeAll: isFullWidth,
                    visible: shelfVisible.indices.contains(1) ? shelfVisible[1] : false,
                    thumbSize: thumbSize,
                    thumbHeight: thumbHeight
                )

                Spacer(minLength: 0)

                shelfRow(
                    title: L10n.closetShelfDresses,
                    garments: vm.dressGarments,
                    category: .dresses,
                    disabled: vm.isTypeDisabled(.dress),
                    vm: vm,
                    isFullWidth: isFullWidth,
                    showSeeAll: isFullWidth,
                    visible: shelfVisible.indices.contains(2) ? shelfVisible[2] : false,
                    thumbSize: thumbSize,
                    thumbHeight: thumbHeight
                )

                Spacer(minLength: 0)

                shelfRow(
                    title: L10n.closetShelfShoes,
                    garments: vm.shoeGarments,
                    category: .shoes,
                    disabled: false,
                    vm: vm,
                    isFullWidth: isFullWidth,
                    showSeeAll: isFullWidth,
                    visible: shelfVisible.indices.contains(3) ? shelfVisible[3] : false,
                    thumbSize: thumbSize,
                    thumbHeight: thumbHeight
                )

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Shelf Row

    private func shelfRow(
        title: String,
        garments: [Garment],
        category: ShelfCategory,
        disabled: Bool,
        vm: ClosetViewModel,
        isFullWidth: Bool,
        showSeeAll: Bool,
        visible: Bool,
        thumbSize: CGFloat,
        thumbHeight: CGFloat
    ) -> some View {
        let _ = cacheVersion

        return VStack(alignment: .trailing, spacing: 4) {
            // Fixed-height item area — consistent spacing whether items exist or not
            Group {
                if vm.isLoadingGarments {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.bgSecondary)
                                .frame(width: thumbSize, height: thumbHeight)
                                .shimmer()
                        }
                    }
                } else if !garments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isFullWidth ? 12 : 8) {
                            ForEach(garments) { garment in
                                garmentThumbnail(garment: garment, vm: vm, size: thumbSize, height: thumbHeight)
                                    .onAppear {
                                        if garment.id == garments.last?.id {
                                            Task { await vm.loadMoreGarments() }
                                        }
                                    }
                            }

                            // "See All" — sadece shelvesFocus (en sağ sayfa) modunda göster
                            if showSeeAll {
                                Button {
                                    selectedCategory = category
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.proGold)
                                        Text("See All")
                                            .font(STFont.labelXSmall)
                                            .foregroundColor(.proGold)
                                    }
                                    .frame(width: thumbSize, height: thumbHeight)
                                }
                            }
                        }
                        .padding(.leading, isFullWidth ? 16 : 2)
                        .padding(.trailing, 8)
                        .padding(.vertical, 2)
                    }
                } else {
                    // Empty — keep same height
                    Color.clear
                }
            }
            .frame(height: thumbHeight + 6)

            // Custom wooden shelf
            WoodenShelf(colorScheme: closetColorScheme)

            // Title (below shelf)
            HStack {
                Spacer()
                Text(title)
                    .font(isFullWidth ? STFont.labelLarge : STFont.labelMedium)
                    .foregroundColor(.textSecondary)
            }
            .padding(.trailing, 12)
        }
        .opacity(disabled ? 0.4 : 1.0)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: visible)
    }

    // MARK: - Garment Thumbnail

    private func garmentThumbnail(garment: Garment, vm: ClosetViewModel, size: CGFloat, height: CGFloat) -> some View {
        let isSelected = vm.selectedGarments[garment.type]?.id == garment.id
        let isMarkedForDeletion = selectedForDeletion.contains(garment.id)
        let image = vm.garmentImage(for: garment.id)

        return Button {
            guard isPro else { showPaywall = true; return }
            if isDeleteMode {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isMarkedForDeletion {
                        selectedForDeletion.remove(garment.id)
                    } else {
                        selectedForDeletion.insert(garment.id)
                    }
                }
                HapticManager.shared.light()
            } else {
                if isSelected {
                    vm.deselectGarment(type: garment.type)
                } else if let img = image {
                    vm.selectGarment(garment, image: img)
                }
            }
        } label: {
            ZStack(alignment: .topLeading) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: height)
                } else {
                    Color.bgSecondary
                        .frame(width: size, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }

                // Delete mode checkbox
                if isDeleteMode {
                    ZStack {
                        Circle()
                            .fill(isMarkedForDeletion ? Color.error : Color.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.15), radius: 2)

                        Image(systemName: isMarkedForDeletion ? "checkmark" : "circle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isMarkedForDeletion ? .white : .textSecondary)
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isDeleteMode
                            ? (isMarkedForDeletion ? Color.error : Color.clear)
                            : (isSelected ? Color.proGold : Color.clear),
                        lineWidth: 2
                    )
                    .padding(-2)
            )
        }
        .contextMenu {
            if !isDeleteMode {
                Button(role: .destructive) {
                    garmentToDelete = garment
                    showDeleteConfirmation = true
                } label: {
                    Label(L10n.commonDelete, systemImage: "trash")
                }
            }
        }
        .disabled(!isDeleteMode && vm.isTypeDisabled(garment.type))
    }

    // MARK: - Floating Dress Me Button

    private func floatingDressMeButton(vm: ClosetViewModel) -> some View {
        Button {
            guard isPro else { showPaywall = true; return }
            if vm.isProcessing { return }
            Task {
                await vm.performTryOn()
                if vm.resultImage != nil {
                    showResultSheet = true
                } else if let error = vm.errorMessage {
                    if error == L10n.tryonInsufficientCredits {
                        showToast(.error, error)
                        showCreditSheet = true
                    } else {
                        showToast(.error, error)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.closetDressMe)
                    .font(STFont.button)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.accent)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
        }
        .disabled(vm.isProcessing)
        .padding(.bottom, 24)
    }

    // MARK: - Delete Banner

    private func deleteBanner(vm: ClosetViewModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            if selectedForDeletion.isEmpty {
                Text(L10n.closetSelectToDelete)
                    .font(STFont.captionMedium)
                    .foregroundColor(.white)
            } else {
                Spacer()
            }

            Spacer()

            if !selectedForDeletion.isEmpty {
                Button {
                    let garmentsToDelete = vm.allGarments.filter { selectedForDeletion.contains($0.id) }
                    Task {
                        await vm.deleteGarments(garmentsToDelete)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedForDeletion.removeAll()
                            isDeleteMode = false
                        }
                    }
                } label: {
                    Text(L10n.closetDeleteSelected(selectedForDeletion.count))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.error.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func shelfCategory(for type: GarmentType) -> ShelfCategory {
        switch type {
        case .top, .jacket: return .topsJackets
        case .bottom: return .bottoms
        case .dress: return .dresses
        case .shoes: return .shoes
        default: return .topsJackets
        }
    }

    // MARK: - Setup

    private func setupViewModel() {
        guard viewModel == nil else { return }

        if let preloaded = appContainer.closetViewModel {
            self.viewModel = preloaded
            return
        }

        guard let userId = appContainer.authRepository.getCurrentUserId() else { return }

        let vm = ClosetViewModel(
            garmentRepository: appContainer.garmentRepository,
            userRepository: appContainer.userRepository,
            storageRepository: appContainer.storageRepository,
            lookRepository: appContainer.lookRepository,
            tryOnService: appContainer.tryOnService,
            currentUserId: userId
        )
        self.viewModel = vm
        appContainer.closetViewModel = vm

        Task {
            await vm.loadClosetData()
            if let user = try? await appContainer.userRepository.getUser(id: userId) {
                closetColorScheme = ClosetColorScheme.scheme(for: user.closetColor)
            }
        }
    }

    // MARK: - Toast Helper

    private func showToast(_ type: Toast.ToastType, _ message: String) {
        withAnimation {
            toast = Toast(type: type, message: message)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                toast = nil
            }
        }
    }
}

// MARK: - Swipe Hint Banner

private struct SwipeHintBanner: View {
    let onDismiss: () -> Void
    @State private var handOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Animated hand
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .offset(x: handOffset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatCount(3, autoreverses: true)
                    ) {
                        handOffset = -12
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.closetSwipeHintLeft)
                    .font(STFont.captionMedium)
                    .foregroundColor(.white)
                Text(L10n.closetSwipeHintRight)
                    .font(STFont.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.accent.opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Closet Mode Toggle

private struct ClosetModeToggle: View {
    @Binding var viewMode: ClosetViewMode

    private let modes: [ClosetViewMode] = [.modelFocus, .split, .shelvesFocus]

    private var selectedIndex: Int {
        modes.firstIndex(of: viewMode) ?? 1
    }

    var body: some View {
        GeometryReader { geo in
            let segmentWidth = geo.size.width / 3

            ZStack(alignment: .leading) {
                // Sliding indicator
                Capsule()
                    .fill(Color.accent)
                    .frame(width: segmentWidth - 4, height: geo.size.height - 4)
                    .offset(x: CGFloat(selectedIndex) * segmentWidth + 2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedIndex)

                // Labels
                HStack(spacing: 0) {
                    modeButton(icon: "person.fill", label: nil, mode: .modelFocus, segmentWidth: segmentWidth)
                    modeButton(icon: "person.fill", label: "tshirt.fill", mode: .split, segmentWidth: segmentWidth)
                    modeButton(icon: "tshirt.fill", label: nil, mode: .shelvesFocus, segmentWidth: segmentWidth)
                }
            }
        }
        .frame(width: 180, height: 36)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
        )
        .overlay(
            Capsule()
                .stroke(Color.textSecondary.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func modeButton(icon: String, label: String?, mode: ClosetViewMode, segmentWidth: CGFloat) -> some View {
        let isActive = viewMode == mode

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewMode = mode
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                if let label {
                    Image(systemName: label)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(isActive ? .white : .textSecondary)
            .frame(width: segmentWidth, height: 36)
        }
    }
}
