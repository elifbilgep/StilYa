//
//  HomeView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI
import RevenueCat
import FirebaseAuth
import Combine

struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var showCart = false
    @State private var showProView = false
    @State private var showCreditSheet = false
    @State private var cartItemCount = 0
    @State private var userCredits = 0
    @State private var userIsPro = RevenueCatManager.shared.isProActive
    @State private var userGender: String? = nil // "male", "female", "unspecified" or nil
    @State private var toast: Toast?
    @State private var userName: String = ""
    @State private var profileImage: UIImage?
    @State private var debugTapCount = 0
    @State private var recentLooksRefresh = 0
    // Closet overlay
    @State private var closetPhase: ClosetAnimationPhase = .idle
    @State private var showClosetOverlay = false
    @State private var closetLeftDoor: Double = 0
    @State private var closetRightDoor: Double = 0
    @State private var closetGlowScale: CGFloat = 0.1
    @State private var closetGlowOpacity: Double = 0
    // Drawer (Pro closet)
    @State private var drawerTilt1: Double = 0
    @State private var drawerTilt2: Double = 0
    @State private var drawerTilt3: Double = 0
    // Weather tip
    @State private var weatherTipProvider = WeatherTipProvider()
    @State private var userClosetColorScheme: ClosetColorScheme = .darkWoodScheme
    // Location permission alert
    @State private var showLocationAlert = false
    // Pro staggered entrance animation
    @State private var proAppeared = false
    // Pending model photo (deferred from onboarding)
    @State private var pendingModelResult: UIImage? = nil
    @State private var showPendingModelSheet = false
    @State private var isGeneratingPendingModel = false

    var body: some View {
        VStack(spacing: 0) {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()


            ScrollView(showsIndicators: false) {
                VStack(spacing: dynamicSpacing) {
                    // Header: profile (left) + greeting/tip + cart (right)
                    HStack(alignment: .center, spacing: 12) {
                    // Profile avatar (left)
                    Button {
                        router.push(.profile)
                    } label: {
                        ProfileAvatar(image: profileImage, size: 42)
                    }

                    // Greeting
                    Text(userName.isEmpty ? L10n.homeTitle : L10n.homeTitleWithName(userName))
                        .font(STFont.displayTitle)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 4)

                    // Remaining tries — hang tag, opens the credit sheet
                    Button {
                        showCreditSheet = true
                    } label: {
                        CreditTag(text: L10n.homeCreditTag(userCredits))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.homeCreditTag(userCredits))
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                layoutA
                }
                .padding(.top, 14)
                .padding(.bottom, 40)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                await loadUserCredits()
            }

            // Closet overlay (flash + content page)
            if showClosetOverlay {
                ClosetTransitionOverlay(
                    phase: $closetPhase,
                    isPresented: $showClosetOverlay
                )
                .transition(.opacity)
            }
        }

        } // VStack
        .onChange(of: showClosetOverlay) { _, isShowing in
            if !isShowing {
                // Reset all animation states
                closetLeftDoor = 0
                closetRightDoor = 0
                drawerTilt1 = 0
                drawerTilt2 = 0
                drawerTilt3 = 0
                closetGlowScale = 0.1
                closetGlowOpacity = 0
                closetPhase = .idle
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(showClosetOverlay ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $showCart, onDismiss: {
            // Reload cart count when sheet closes
            Task {
                await loadCartItemCount()
            }
        }) {
            NavigationView {
                CartView()
            }
            .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showProView, onDismiss: {
            Task {
                await loadUserCredits()
                checkPendingModelGeneration()
            }
        }) {
            ProView()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showCreditSheet, onDismiss: {
            Task { await loadUserCredits() }
        }) {
            HomeCreditSheet()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showPendingModelSheet) {
            PendingModelResultSheet(image: pendingModelResult)
                .preferredColorScheme(.light)
        }
        .toast($toast)
        .alert(L10n.weatherLocationAlertTitle, isPresented: $showLocationAlert) {
            Button(L10n.weatherLocationAlertSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.weatherLocationAlertCancel, role: .cancel) {}
        } message: {
            Text(L10n.weatherLocationAlertMessage)
        }
        .task {
            weatherTipProvider.fetch()
            // Run all independent loads in parallel
            async let credits: () = loadUserCredits()
            async let cart: () = loadCartItemCount()
            async let looks: () = loadLooksData()
            _ = await (credits, cart, looks)
            // Lazy fetch offerings if not yet loaded (deferred from app launch)
            if RevenueCatManager.shared.offerings == nil {
                await RevenueCatManager.shared.fetchOfferings()
            }
        }
        .onAppear {
            // Staggered entrance for all users
            if !proAppeared {
                withAnimation(.easeOut(duration: 0.45)) {
                    proAppeared = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .creditsDidUpdate)) { notification in
            if let credits = notification.userInfo?["credits"] as? Int {
                userCredits = credits
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lookSavedInBackground)) { _ in
            // Background save tamamlandı — looks'u yeniden yükle
            Task {
                await container.looksViewModel?.loadLooks(limit: 3)
                await container.looksViewModel?.loadRecentLookImages(count: 3)
                recentLooksRefresh += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lookSaveFailed)) { _ in
            toast = Toast(type: .error, message: L10n.homeLookSaveFailed)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openClosetDeepLink)) { _ in
            openWardrobe()
        }
        .onReceive(NotificationCenter.default.publisher(for: .proStatusDidChange)) { _ in
            Task {
                await loadUserCredits()
                checkPendingModelGeneration()
            }
        }
    }
    
    // MARK: - Methods

    #if DEBUG
    private func debugResetCredits() async {
        guard let userId = container.authRepository.getCurrentUserId() else { return }
        do {
            let url = URL(string: "\(Configuration.shared.apiBaseURL)/api/debug/reset-credits")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(userId, forHTTPHeaderField: "X-User-ID")

            if let user = Auth.auth().currentUser {
                let token = try await user.getIDToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                userCredits = 0
                toast = Toast(type: .success, message: "Krediler sıfırlandı")
            } else {
                toast = Toast(type: .error, message: "Sıfırlama başarısız")
            }
        } catch {
            toast = Toast(type: .error, message: "Hata: \(error.localizedDescription)")
        }
    }
    #endif

    private func loadUserCredits() async {
        guard let userId = container.authRepository.getCurrentUserId() else { return }

        do {
            // Fetch credits and user data in parallel
            async let freshCreditsTask = container.userRepository.getCredits(userId: userId)
            async let userTask = container.userRepository.getUser(id: userId)
            let freshCredits = try await freshCreditsTask

            if let user = try await userTask {
                userCredits = freshCredits
                let rcIsPro = RevenueCatManager.shared.isProActive
                userIsPro = rcIsPro
                userGender = user.gender
                userClosetColorScheme = ClosetColorScheme.scheme(for: user.closetColor)

                // If RevenueCat says Pro but Firestore doesn't have plan (Worker sync failed),
                // use RevenueCat plan as fallback and retry sync in background
                if rcIsPro && user.subscriptionPlan == nil {
                    let maxCredits = (RevenueCatManager.shared.activeSubscriptionPlan == "monthly") ? AppConstants.proMonthlyCredits : AppConstants.proWeeklyCredits
                    userCredits = maxCredits + user.purchasedCredits + user.credits
                    Task { try? await WorkerAPIService.shared.syncPro() }
                }
                #if DEBUG
                print("📊 [HomeView] isPro: \(rcIsPro) | Credits: \(userCredits)")
                #endif
                // Isimden sadece ilk kelimeyi al (orn: "Elif Bilge" -> "Elif")
                // Firestore'da yoksa Firebase Auth'dan fallback
                let fullName = (user.displayName?.isEmpty == false ? user.displayName : Auth.auth().currentUser?.displayName) ?? ""
                if !fullName.isEmpty {
                    userName = fullName.components(separatedBy: " ").first ?? ""
                }

                // Load profile image in background (don't block UI)
                let imagePath = user.profileImagePath
                if profileImage == nil, let path = imagePath, !path.isEmpty {
                    Task.detached { [container] in
                        if let data = try? await container.storageRepository.downloadImage(path: path),
                           let img = UIImage(data: data) {
                            await MainActor.run { profileImage = img }
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
            print("❌ [HomeView] Failed to load credits: \(error)")
            #endif
            toast = Toast(type: .error, message: L10n.homeCreditsLoadFailed)
        }
    }

    private func loadLooksData() async {
        await container.looksViewModel?.loadLooks(limit: 3)
        await container.looksViewModel?.loadRecentLookImages(count: 3)
        recentLooksRefresh += 1
    }

    // MARK: - Pending Model Photo

    private func checkPendingModelGeneration() {
        guard RevenueCatManager.shared.isProActive,
              PendingModelPhotoManager.hasPending,
              !isGeneratingPendingModel else { return }

        isGeneratingPendingModel = true
        Task {
            await generatePendingModelPhoto()
        }
    }

    private func generatePendingModelPhoto() async {
        let selfies = PendingModelPhotoManager.loadSelfies()
        guard let primarySelfie = selfies.first else {
            PendingModelPhotoManager.clear()
            isGeneratingPendingModel = false
            return
        }

        let bodyPhoto = PendingModelPhotoManager.loadBodyPhoto()
        let gender = PendingModelPhotoManager.pendingGender
        let heightCm = PendingModelPhotoManager.pendingHeightCm
        let bodyType = PendingModelPhotoManager.pendingBodyType

        #if DEBUG
        print("🚀 [HomeView] Generating pending model photo in background...")
        #endif

        do {
            let result = try await TryOnService.shared.generateModelPhoto(
                selfie: primarySelfie,
                gender: gender,
                bodyPhoto: bodyPhoto,
                additionalSelfies: Array(selfies.dropFirst()),
                source: "pending_onboarding",
                heightCm: heightCm,
                bodyType: bodyType
            )

            // Upload: bg removal → R2 → Firestore
            guard let userId = container.authRepository.getCurrentUserId() else { return }
            let processedImage = await ImagePreprocessor.shared.removeBackground(result.image)
            let imagePath = try await container.storageRepository.uploadModelImagePNG(processedImage, userId: userId)
            try await container.userRepository.updateModelImagePath(userId: userId, path: imagePath, isAIGenerated: true)

            PendingModelPhotoManager.clear()

            // Show result sheet
            pendingModelResult = result.image
            showPendingModelSheet = true

            // Reload profile image
            await loadUserCredits()

            #if DEBUG
            print("✅ [HomeView] Pending model photo generated & uploaded!")
            #endif
        } catch {
            #if DEBUG
            print("❌ [HomeView] Pending model photo failed: \(error.localizedDescription)")
            #endif
        }

        isGeneratingPendingModel = false
    }

    private func loadCartItemCount() async {
        guard let userId = container.authRepository.getCurrentUserId() else { return }

        do {
            let allGarments = try await container.garmentRepository.getGarments(userId: userId)
            cartItemCount = allGarments.filter { $0.isInCart }.count
        } catch {
            #if DEBUG
            print("❌ [HomeView] Failed to load cart count: \(error)")
            #endif
            toast = Toast(type: .error, message: L10n.homeCartLoadFailed)
        }
    }

    // MARK: - Subviews

    private var tipAccent: Color {
        weatherTipProvider.mood.accentColor
    }

    // MARK: - Layout A (current)

    @ViewBuilder
    /// Dynamic VStack spacing based on screen height
    /// SE/mini (~667pt): 4, Standard (~852pt): 6, Pro Max (~932pt): 10
    private var dynamicSpacing: CGFloat {
        let height = UIScreen.main.bounds.height
        if height >= 920 { return 10 }  // Pro Max
        if height >= 840 { return 6 }   // Standard (15, 16)
        return 4                          // SE, mini
    }

    @ViewBuilder
    private var layoutA: some View {
        // Taped paper strip: weather / daily tip
        tipStrip
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, 10)
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 0))

        // The one primary action
        heroCard
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, 10)
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 1))

        // Wall shelf: recent looks + trend magazine
        shelfScene
            .padding(.top, 18)
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 2))

        // Floor: closet + cart basket
        floorScene
            .padding(.top, 14)
            .zIndex(closetPhase != .idle ? 1 : 0)
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 3))
    }

    // MARK: - Try-On Hero Card

    private var hasLooks: Bool {
        !(container.looksViewModel?.recentLooks.isEmpty ?? true)
    }

    private func startTryOn() {
        if RevenueCatManager.shared.isProActive || userCredits > 0 {
            router.push(.dressUp)
        } else {
            showProView = true
        }
    }

    private var heroCard: some View {
        Button(action: startTryOn) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.homeDressUp)
                        .font(.custom("InstrumentSerif-Regular", size: 34))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(L10n.homeDressUpShort)
                        .font(STFont.bodySmall)
                        .foregroundColor(.textSecondary)
                        .padding(.top, 6)

                    Spacer(minLength: 12)

                    HStack(spacing: 8) {
                        Text(hasLooks ? L10n.homeTryNow : L10n.homeFirstTry)
                            .font(STFont.buttonSmall)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.accent))

                    Text(L10n.homeTryCost(AppConstants.singleTryOnCost))
                        .font(STFont.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.top, 7)
                }
                .padding(.leading, 22)
                .padding(.vertical, 20)

                Spacer(minLength: 8)

                // Collage art — male users get the men's outfit
                Image(userGender == "male" ? "male-combin" : "combin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128)
                    .padding(.vertical, 8)
                    .padding(.trailing, 8)
            }
            .frame(height: 196)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(hex: "#FBF7EE"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color(hex: "#E8DDC2"), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tip Strip (torn paper, taped)

    private var tipStrip: some View {
        ZStack(alignment: .leading) {
            Image("paper")
                .resizable()
                .frame(height: 58)
                .padding(.horizontal, -12)
                .rotationEffect(.degrees(-0.8))
                .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)

            tipContent
                .padding(.horizontal, 22)
        }
        .frame(height: 58)
        .overlay(alignment: .topLeading) {
            WashiTape(width: 56)
                .rotationEffect(.degrees(-9))
                .offset(x: 2, y: -7)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            WashiTape(width: 46)
                .rotationEffect(.degrees(7))
                .offset(x: -2, y: 2)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var tipContent: some View {
        if weatherTipProvider.hasWeatherData, let temp = weatherTipProvider.temperature {
            HStack(spacing: 7) {
                Image(systemName: weatherTipProvider.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.proGold)

                Text(temp)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                Text(weatherTipProvider.tip)
                    .font(STFont.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                // Apple Weather attribution (required by WeatherKit)
                if let url = weatherTipProvider.attributionLegalURL {
                    Link(destination: url) {
                        HStack(spacing: 2) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 9))
                            Text("Weather")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.textSecondary.opacity(0.6))
                    }
                }
            }
        } else if weatherTipProvider.locationDenied {
            Button {
                showLocationAlert = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                    Text(L10n.weatherLocationDeniedHint)
                        .font(STFont.bodyRegular)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 7) {
                Image(systemName: "sparkle")
                    .font(.system(size: 15))
                    .foregroundColor(.proGold)
                Text(weatherTipProvider.tip)
                    .font(STFont.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Shelf Scene (recent looks + trends)

    private var recentLookImages: [UIImage] {
        guard let looksVM = container.looksViewModel else { return [] }
        let _ = recentLooksRefresh
        let _ = looksVM.lookImagesVersion
        return Array(looksVM.recentLooks.prefix(3).compactMap { looksVM.lookImage(for: $0.id) })
    }

    private var shelfScene: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                Spacer()
                Button { router.push(.looks) } label: {
                    ShelfPolaroidStack(images: recentLookImages)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.homeRecentLooks)
                Spacer()
                Button { router.push(.trendMagazine) } label: {
                    TrendMagazineCard()
                        .scaleEffect(0.72)
                        .frame(width: 104, height: 140)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.homeTrendsShelf)
                Spacer()
            }
            .frame(height: 140)
            .padding(.horizontal, Spacing.screenHorizontal)

            WoodenPlank()
                .padding(.horizontal, Spacing.screenHorizontal)

            HStack(spacing: 0) {
                Spacer()
                Text(L10n.homeRecentLooks).frame(width: 130)
                Spacer()
                Text(L10n.homeTrendsShelf).frame(width: 104)
                Spacer()
            }
            .font(.custom("Bradley Hand", size: 18))
            .foregroundColor(.textPrimary.opacity(0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.top, 6)
            .padding(.horizontal, Spacing.screenHorizontal)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Floor Scene (closet + cart basket)

    private var floorScene: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                Spacer()
                Button(action: { openWardrobe() }) {
                    WardrobeIllustration(
                        leftDoorRotation: closetLeftDoor,
                        rightDoorRotation: closetRightDoor,
                        colorScheme: userClosetColorScheme
                    )
                    .frame(width: 128, height: 166)
                    .overlay { closetGlowOverlay }
                    .overlay {
                        if !userIsPro {
                            ProHangTag()
                                .rotationEffect(.degrees(12))
                                .offset(x: 16, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.closetTitle)
                Spacer()
                Button { showCart = true } label: {
                    basketView
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.cartTitle)
                Spacer()
            }
            .frame(height: 168)
            .padding(.horizontal, Spacing.screenHorizontal)

            Rectangle()
                .fill(Color.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                Spacer()
                Text(L10n.closetTitle).frame(width: 136)
                Spacer()
                Text(L10n.cartTitle).frame(width: 164)
                Spacer()
            }
            .font(.custom("Bradley Hand", size: 18))
            .foregroundColor(.textPrimary.opacity(0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.top, 6)
            .padding(.horizontal, Spacing.screenHorizontal)
            .accessibilityHidden(true)
        }
    }

    /// Decorative garments that always sit in the basket (the badge shows the real count).
    private var basketItems: [BasketItem] {
        if userGender == "male" {
            return [
                BasketItem(name: "showcase-bottom", size: 74, x: -40, y: -36, angle: -18),
                BasketItem(name: "brown-jacket", size: 90, x: 8, y: -40, angle: -4)
            ]
        }
        return [
            BasketItem(name: "bottom", size: 74, x: -41, y: -36, angle: -20),
            BasketItem(name: "top", size: 72, x: 42, y: -38, angle: 16),
            BasketItem(name: "jacket", size: 84, x: 0, y: -42, angle: -3)
        ]
    }

    private var basketView: some View {
        ZStack(alignment: .bottom) {
            ForEach(basketItems) { item in
                Image(item.name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: item.size, height: item.size)
                    .rotationEffect(.degrees(item.angle))
                    .offset(x: item.x, y: item.y)
            }

            Image("wire-basket")
                .resizable()
                .scaledToFit()
                .frame(width: 164, height: 74)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 4)
        }
        .frame(width: 164, height: 140, alignment: .bottom)
        .overlay(alignment: .topTrailing) {
            if cartItemCount > 0 {
                Text("\(cartItemCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Circle().fill(Color.accent))
                    .offset(x: 6, y: 44)
            }
        }
    }

    // MARK: - Cart Preview Card (Pro layout)

    private var cartPreviewCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Image("basket")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)

                Image("jacket")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -28, y: -30)

                Image("bottom")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(8))
                    .offset(x: 30, y: 3)

                Image("top")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-5))
                    .offset(x: -19, y: 32)

                if cartItemCount > 0 {
                    Text("\(cartItemCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Circle().fill(Color.accent))
                        .offset(x: 60, y: -55)
                }
            }

            Text(L10n.cartTitle)
                .font(STFont.labelMedium)
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drawer Section (Pro closet)

    private var drawerSection: some View {
        Button(action: {
            openDrawer()
        }) {
            DrawerCardView(
                drawer1Tilt: drawerTilt1,
                drawer2Tilt: drawerTilt2,
                drawer3Tilt: drawerTilt3,
                colorScheme: userClosetColorScheme
            )
            .overlay {
                closetGlowOverlay
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.screenHorizontal + 30)
        .padding(.top, 8)
    }

    // MARK: - Closet Glow Overlay (shared)

    @ViewBuilder
    private var closetGlowOverlay: some View {
        if closetPhase == .doorsOpening || closetPhase == .glowExpanding {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.7),
                    Color(hex: "#FFF8E7").opacity(0.5),
                    Color(hex: "#C9A962").opacity(0.25),
                    Color.bgPrimary.opacity(0.1),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 150
            )
            .scaleEffect(closetGlowScale)
            .opacity(closetGlowOpacity)
            .allowsHitTesting(false)
        }

        if closetPhase == .glowExpanding {
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ForEach(0..<8, id: \.self) { i in
                    ClosetSparkleParticle(index: i, center: center)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Animation Functions

    private func openWardrobe() {
        guard closetPhase == .idle else { return }
        closetPhase = .doorsOpening
        HapticManager.shared.medium()

        withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
            closetLeftDoor = -70
            closetRightDoor = 70
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            closetGlowScale = 1.0
            closetGlowOpacity = 0.3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard closetPhase == .doorsOpening else { return }
            closetPhase = .glowExpanding
            withAnimation(.easeOut(duration: 0.7)) {
                closetGlowScale = 8.0
                closetGlowOpacity = 0.6
            }
            showClosetOverlay = true
        }
    }

    private func openDrawer() {
        guard closetPhase == .idle else { return }
        closetPhase = .doorsOpening
        HapticManager.shared.medium()

        // Staggered drawer tilt (faster)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            drawerTilt1 = 25
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.06)) {
            drawerTilt2 = 25
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.12)) {
            drawerTilt3 = 25
        }

        // Glow leaks from drawer
        withAnimation(.easeOut(duration: 0.25).delay(0.2)) {
            closetGlowScale = 1.0
            closetGlowOpacity = 0.3
        }

        // Expand + overlay (faster)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard closetPhase == .doorsOpening else { return }
            closetPhase = .glowExpanding
            withAnimation(.easeOut(duration: 0.4)) {
                closetGlowScale = 8.0
                closetGlowOpacity = 0.6
            }
            showClosetOverlay = true
        }
    }

}

// MARK: - Pro Staggered Entrance Modifier

private struct ProStaggerModifier: ViewModifier {
    let show: Bool
    let isPro: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 18)
            .animation(
                .easeOut(duration: 0.45).delay(Double(index) * 0.12),
                value: show
            )
    }
}

// MARK: - Home Scene Pieces

/// A garment drawn in the cart basket (offset from the basket's bottom center).
private struct BasketItem: Identifiable {
    let name: String
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let angle: Double
    var id: String { name }
}

/// Three polaroids standing on the shelf: the latest looks, or blank frames for new users.
private struct ShelfPolaroidStack: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    let images: [UIImage]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            polaroid(images.count > 2 ? images[2] : nil, showPlaceholder: false)
                .rotationEffect(.degrees(-7))
                .offset(x: 6, y: -2)
            polaroid(images.count > 1 ? images[1] : nil, showPlaceholder: false)
                .rotationEffect(.degrees(6))
                .offset(x: 30, y: -4)
            polaroid(images.first, showPlaceholder: images.isEmpty)
                .rotationEffect(.degrees(-1))
                .offset(x: 17)
        }
        .frame(width: 130, height: 136, alignment: .bottomLeading)
    }

    private func polaroid(_ image: UIImage?, showPlaceholder: Bool) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 90)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(hex: "#F1EFE8"))
                    .frame(width: 84, height: 90)
                if showPlaceholder {
                    Text(L10n.homeFirstLookHere)
                        .font(.custom("Bradley Hand", size: 14))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding([.top, .horizontal], 6)
        .padding(.bottom, 22)
        .background(Color.white)
        .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

/// Wall shelf plank: lit top face + darker front edge.
private struct WoodenPlank: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(hex: "#E9D3B0")).frame(height: 10)
            Rectangle().fill(Color(hex: "#C9A57A")).frame(height: 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: Color(hex: "#785A32").opacity(0.15), radius: 6, x: 0, y: 6)
    }
}

/// Kraft hang tag with a string, showing the remaining tries.
private struct CreditTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("Bradley Hand", size: 18))
            .fontWeight(.bold)
            .foregroundColor(Color(hex: "#5C4A26"))
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 32)
            .padding(.trailing, 12)
            .frame(height: 42)
            .background(
                HangTagShape()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#F0E4C8"), Color(hex: "#E2CFA6")],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color.bgPrimary)
                    .overlay(Circle().stroke(Color(hex: "#CDB88C"), lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .offset(x: 13)
            }
            .overlay(alignment: .topLeading) {
                TagStringShape()
                    .stroke(Color(hex: "#8A7A5E"), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .frame(width: 34, height: 26)
                    .offset(x: -14, y: -4)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color(hex: "#503C1E").opacity(0.2), radius: 2, x: 0, y: 2)
            .rotationEffect(.degrees(6))
    }
}

/// Small "Pro" tag hung on the closet door knob for free users.
private struct ProHangTag: View {
    var body: some View {
        Text("Pro")
            .font(.custom("DMSans-SemiBold", size: 11))
            .foregroundColor(Color(hex: "#7A6328"))
            .padding(.leading, 10)
            .padding(.trailing, 7)
            .padding(.vertical, 2)
            .background(HangTagShape(notch: 6).fill(Color(hex: "#F5EFE0")))
            .overlay(HangTagShape(notch: 6).stroke(Color(hex: "#C9A962"), lineWidth: 1))
    }
}

/// Tag outline: rectangle with a pointed left end.
private struct HangTagShape: Shape {
    var notch: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 3), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 3))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 3, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

/// Two strands of string running from the tag's hole up and to the left.
private struct TagStringShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 52, sy = rect.height / 44
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var p = Path()
        p.move(to: pt(49, 41))
        p.addCurve(to: pt(4, 2), control1: pt(38, 34), control2: pt(26, 16))
        p.move(to: pt(49, 41))
        p.addCurve(to: pt(12, -2), control1: pt(42, 28), control2: pt(30, 10))
        return p
    }
}

/// Translucent washi tape with torn, zigzag ends.
private struct WashiTape: View {
    let width: CGFloat

    var body: some View {
        TornTapeShape()
            .fill(Color(hex: "#ECE2C6").opacity(0.8))
            .frame(width: width, height: width > 50 ? 20 : 18)
    }
}

private struct TornTapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [
            (0.03, 0), (0.97, 0), (1, 0.15), (0.96, 0.30), (1, 0.50), (0.96, 0.70), (1, 0.85), (0.97, 1),
            (0.03, 1), (0, 0.85), (0.04, 0.70), (0, 0.50), (0.04, 0.30), (0, 0.15)
        ]
        var p = Path()
        for (i, (x, y)) in pts.enumerated() {
            let point = CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Trend Magazine Card Component

private struct TrendMagazineCard: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    var body: some View {
        ZStack(alignment: .leading) {
            // Arka sayfa — kıvrımın arkasında görünen kısım
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.82), Color(white: 0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 135, height: 190)
                .offset(x: -5)

            // Ana dergi kartı — tipografi odaklı, Vogue/Harper's Bazaar tarzı
            ZStack {
                // Koyu arka plan
                Color(hex: "#1A1A1A")

                VStack(spacing: 0) {
                    Spacer()

                    // Üst dekoratif çizgi
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 26, height: 0.5)

                    Spacer()
                        .frame(height: 12)

                    // Ana başlık — büyük editorial tipografi
                    Text(L10n.homeTrendCardTitle)
                        .font(.custom("InstrumentSerif-Regular", size: 25))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 135, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            // Sol kenardan kıvrım — 3D perspektif
            .overlay(alignment: .leading) {
                MagazineCurlOverlay()
                    .frame(width: 32)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8)
                    )
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 10, x: 3, y: 5)
    }
}

// MARK: - Magazine Page Curl Overlay

private struct MagazineCurlOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                // 1. Sayfa kıvrımı gölgesi — soldan sağa azalan karanlık
                var shadowPath = Path()
                shadowPath.addRect(CGRect(x: 0, y: 0, width: w, height: h))

                context.fill(
                    shadowPath,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color.black.opacity(0.4), location: 0),
                            .init(color: Color.black.opacity(0.15), location: 0.35),
                            .init(color: Color.black.opacity(0.05), location: 0.6),
                            .init(color: Color.clear, location: 1.0),
                        ]),
                        startPoint: CGPoint(x: 0, y: h * 0.5),
                        endPoint: CGPoint(x: w, y: h * 0.5)
                    )
                )

                // 2. Kağıdın döndüğü kenar — parlak highlight çizgisi
                var highlightPath = Path()
                highlightPath.move(to: CGPoint(x: w * 0.3, y: 0))
                highlightPath.addLine(to: CGPoint(x: w * 0.25, y: h))

                context.stroke(
                    highlightPath,
                    with: .color(.white.opacity(0.5)),
                    lineWidth: 1.5
                )

                // 3. Kıvrılmış kağıt arka yüzü — sol kenarda açık gri şerit
                var backPagePath = Path()
                backPagePath.move(to: CGPoint(x: 0, y: 0))
                backPagePath.addLine(to: CGPoint(x: w * 0.22, y: 0))
                backPagePath.addLine(to: CGPoint(x: w * 0.18, y: h))
                backPagePath.addLine(to: CGPoint(x: 0, y: h))
                backPagePath.closeSubpath()

                context.fill(
                    backPagePath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(white: 0.95),
                            Color(white: 0.85),
                            Color(white: 0.78),
                        ]),
                        startPoint: CGPoint(x: 0, y: h * 0.5),
                        endPoint: CGPoint(x: w * 0.22, y: h * 0.5)
                    )
                )

                // 4. Arka yüz kenarında ince gölge çizgisi
                var edgeShadow = Path()
                edgeShadow.move(to: CGPoint(x: w * 0.22, y: 0))
                edgeShadow.addLine(to: CGPoint(x: w * 0.18, y: h))

                context.stroke(
                    edgeShadow,
                    with: .color(.black.opacity(0.15)),
                    lineWidth: 1
                )
            }
        }
    }
}

// MARK: - Home Credit Sheet

struct HomeCreditSheet: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) var dismiss
    @State private var referralCode: String = ""
    @State private var isLoadingCode = false
    @State private var showShareSheet = false
    @State private var codeCopied = false
    @State private var selectedPack: CreditPack?
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showPaywall = false
    @State private var toast: Toast?

    /// RevenueCat package'ını product identifier ile bul
    private func findPackage(_ productId: String) -> Package? {
        revenueCatManager.currentPackages.first(where: {
            $0.storeProduct.productIdentifier == productId
        })
    }

    private var creditPacks: [CreditPack] {
        let pack5 = findPackage("5_credit")
        let pack20 = findPackage("20_credit")
        let pack60 = findPackage("60_credit")

        // Base price per credit (from smallest pack) for savings calculation
        let basePPC: Decimal? = pack5.map { $0.storeProduct.price / Decimal(AppConstants.creditPack5Amount) }

        return [
            CreditPack.make(
                id: AppConstants.creditPack5ID,
                credits: AppConstants.creditPack5Amount,
                badge: nil,
                package: pack5,
                basePricePerCredit: nil
            ),
            CreditPack.make(
                id: AppConstants.creditPack20ID,
                credits: AppConstants.creditPack20Amount,
                badge: L10n.homeBestValue,
                package: pack20,
                basePricePerCredit: basePPC
            ),
            CreditPack.make(
                id: AppConstants.creditPack60ID,
                credits: AppConstants.creditPack60Amount,
                badge: L10n.homeMegaPack,
                package: pack60,
                basePricePerCredit: basePPC
            ),
        ]
    }

    /// RevenueCat paketleri yüklendi mi?
    private var hasPackages: Bool {
        !revenueCatManager.currentPackages.isEmpty
    }

    var body: some View {
        NavigationStack {
            if !hasPackages {
                // RevenueCat paketleri yoksa sheet'i kapat
                Color.clear
                    .onAppear { dismiss() }
            } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Credit Packs Title
                    VStack(spacing: 4) {
                        Text(L10n.homeBuyCredits)
                            .font(STFont.displaySmall)
                            .foregroundColor(.textPrimary)

                        Text(L10n.homeBuyCreditsSubtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 8)

                    if !revenueCatManager.isProActive {
                        // MARK: - Pro Upsell (sadece free user)
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 14) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(L10n.proUpgrade)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)

                                        Text(L10n.homeRecommended)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.proGold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(Color.white)
                                            )
                                    }

                                    Text(L10n.proWeeklyCreditsDesc(AppConstants.proWeeklyCredits) + " • \(revenueCatManager.weeklyPackage?.storeProduct.localizedPriceString ?? AppConstants.proWeeklyPriceTR)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))

                                    Text(L10n.proComboFeature)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.proGold, Color(hex: "#B8943D")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.proGold.opacity(0.3), radius: 8, y: 4)
                        }

                        // MARK: - Divider
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.2))
                                .frame(height: 1)
                            Text(L10n.homeOrBuyCredits)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .layoutPriority(1)
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.2))
                                .frame(height: 1)
                        }
                    }

                    // MARK: - Credit Pack Cards
                    VStack(spacing: 12) {
                        ForEach(creditPacks) { pack in
                            CreditPackRow(
                                pack: pack,
                                isSelected: selectedPack?.id == pack.id,
                                onTap: { selectedPack = pack }
                            )
                        }
                    }

                    // MARK: - Purchase Button
                    Button(action: {
                        Task { await purchaseSelectedPack() }
                    }) {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 16))
                                if let pack = selectedPack {
                                    Text(L10n.homeBuyButton(pack.price))
                                        .font(.system(size: 16, weight: .semibold))
                                } else {
                                    Text(L10n.homeSelectPackage)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                .fill(selectedPack != nil ? Color.accent : Color.accent.opacity(0.4))
                        )
                    }
                    .disabled(selectedPack == nil || isPurchasing)

                    // Error message
                    if let purchaseError {
                        Text(purchaseError)
                            .font(.system(size: 13))
                            .foregroundColor(.error)
                    }

                    // MARK: - Referral Box (compact)
                    referralBox

                    Text(L10n.homeCreditsNeverExpire)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    // Terms of Use & Privacy Policy links
                    HStack(spacing: 4) {
                        Link(L10n.profileTermsOfUse, destination: LegalURLs.termsOfUse)
                        Text("·")
                            .foregroundColor(.textSecondary.opacity(0.5))
                        Link(L10n.profilePrivacyPolicy, destination: LegalURLs.privacyPolicy)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary.opacity(0.7))
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
            .background(Color.bgPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.commonClose) { dismiss() }
                        .foregroundColor(.textPrimary)
                }
            }
            } // else hasPackages
        }
        .sheet(isPresented: $showPaywall) {
            ProView(onPurchaseSuccess: {
                showPaywall = false
                dismiss()
            })
            .preferredColorScheme(.light)
        }
        .shareSheet(isPresented: $showShareSheet, items: ShareableContent.referralCode(referralCode))
        .toast($toast)
        .task {
            // En büyük kredi paketi varsayılan seçili gelsin
            if selectedPack == nil {
                selectedPack = creditPacks.first(where: { $0.credits == AppConstants.creditPack60Amount })
            }
            await loadReferralCode()
        }
    }

    // MARK: - Purchase

    private func purchaseSelectedPack() async {
        guard let pack = selectedPack, let package = pack.package else {
            purchaseError = L10n.proPurchaseError
            return
        }

        isPurchasing = true
        purchaseError = nil

        do {
            // Ödeme başarılı olana kadar bekle — iptal veya hata olursa catch'e düşer
            let customerInfo = try await revenueCatManager.purchase(package: package)

            // Transaction ID al — Worker'da duplicate koruması için kullanılacak
            let transactionId = customerInfo.nonSubscriptionTransactions
                .sorted(by: { $0.purchaseDate > $1.purchaseDate })
                .first?.transactionIdentifier

            // Worker üzerinden kredi ekle (server-side doğrulama + Firestore güncellemesi)
            // Gerçek App Store product ID'sini gönder (pack.id Constants'tan geliyor, package.storeProduct gerçek ID)
            let realProductId = package.storeProduct.productIdentifier
            try await WorkerAPIService.shared.verifyPurchase(
                productId: realProductId,
                transactionId: transactionId
            )

            toast = Toast(type: .success, message: L10n.homeCreditsPurchased(pack.credits))
            dismiss()
        } catch is CancellationError {
            // Kullanıcı iptal etti — kredi eklenmez
        } catch {
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                // User cancelled via StoreKit
            } else {
                purchaseError = L10n.proPurchaseError
            }
        }

        isPurchasing = false
    }

    // MARK: - Referral Box
    private var referralBox: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.proGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.homeInviteFriend)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Text(L10n.homeInviteShareCode(AppConstants.referralBonusCredits))
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Share button
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.proGold)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.proGold.opacity(0.12))
                        )
                }
            }

            // Code row
            if isLoadingCode {
                ProgressView()
                    .frame(height: 36)
            } else {
                HStack(spacing: 8) {
                    Text(referralCode)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button(action: {
                        UIPasteboard.general.string = referralCode
                        codeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            codeCopied = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(codeCopied ? L10n.commonCopied : L10n.homeCopy)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(codeCopied ? .success : .proGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(codeCopied ? Color.success.opacity(0.1) : Color.proGold.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.bgSecondary)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .fill(Color.bgPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                        .strokeBorder(Color.proGold.opacity(0.3), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.proGold.opacity(0.08), radius: 8, y: 2)
    }

    private func loadReferralCode() async {
        isLoadingCode = true
        guard let userId = container.authRepository.getCurrentUserId() else {
            isLoadingCode = false
            return
        }

        do {
            let code = try await container.referralRepository.generateReferralCode(for: userId)
            referralCode = code
        } catch {
            #if DEBUG
            print("❌ [HomeCreditSheet] Failed to get referral code: \(error)")
            #endif
            referralCode = L10n.profileCodeError
        }
        isLoadingCode = false
    }
}

// MARK: - Credit Pack Model

private struct CreditPack: Identifiable {
    let id: String
    let credits: Int
    let price: String
    let badge: String?
    let pricePerCredit: String
    let savingsPercent: Int? // nil for base pack
    var package: Package? = nil // RevenueCat package reference

    /// Dynamically build a CreditPack — price & pricePerCredit from RevenueCat
    static func make(
        id: String, credits: Int, badge: String?,
        package: Package?, basePricePerCredit: Decimal?
    ) -> CreditPack {
        guard let pkg = package else {
            return CreditPack(id: id, credits: credits, price: "—", badge: badge,
                              pricePerCredit: "—", savingsPercent: nil, package: nil)
        }

        let price = pkg.storeProduct.localizedPriceString
        let ppc = pkg.storeProduct.price / Decimal(credits)

        // Format pricePerCredit with same locale as store product
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = pkg.storeProduct.priceFormatter?.locale ?? .current
        formatter.maximumFractionDigits = 2
        let ppcString = formatter.string(from: ppc as NSDecimalNumber) ?? "—"

        // Calculate savings vs base pack
        var savings: Int? = nil
        if let base = basePricePerCredit, base > 0 {
            let pct = ((base - ppc) / base) * 100
            let rounded = NSDecimalNumber(decimal: pct).intValue
            if rounded > 0 { savings = rounded }
        }

        return CreditPack(id: id, credits: credits, price: price, badge: badge,
                          pricePerCredit: ppcString, savingsPercent: savings, package: pkg)
    }
}

// MARK: - Credit Pack Row

private struct CreditPackRow: View {
    let pack: CreditPack
    let isSelected: Bool
    let onTap: () -> Void

    private var isBestValue: Bool {
        pack.savingsPercent != nil && pack.savingsPercent! >= 30
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Credit amount
                    VStack(spacing: 0) {
                        Text("\(pack.credits)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isBestValue ? .proGold : (isSelected ? .proGold : .textPrimary))
                        Text(L10n.homeCredit)
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(width: 56)

                    // Divider
                    Rectangle()
                        .fill(Color.textSecondary.opacity(0.15))
                        .frame(width: 1, height: 40)

                    // Price info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pack.price)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color.proGold : Color.textSecondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(Color.proGold)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isBestValue ? Color.proGold.opacity(0.08) : (isSelected ? Color.proGold.opacity(0.06) : Color.bgSecondary))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isBestValue ? Color.proGold.opacity(0.6) : (isSelected ? Color.proGold.opacity(0.5) : Color.clear),
                                lineWidth: isBestValue ? 2 : 1.5
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if let badge = pack.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isBestValue ? Color.proGold : Color.proGold.opacity(0.8))
                        )
                        .offset(x: -8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
}
