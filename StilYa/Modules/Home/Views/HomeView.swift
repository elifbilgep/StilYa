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

                    Spacer()
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
        // Weather card
        weatherCard
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 0))

        // Action Card (single Try Outfit)
        actionCards
            .padding(.top, 2)
            .padding(.bottom, 8)
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 1))

        // Recent Looks + Closet side by side
        HStack(alignment: .center, spacing: 0) {
            recentLooksColumn

            VStack(alignment: .center, spacing: 8) {
                Button(action: { openWardrobe() }) {
                    ClosetCardView(
                        leftDoorRotation: closetLeftDoor,
                        rightDoorRotation: closetRightDoor,
                        colorScheme: userClosetColorScheme
                    )
                    .scaleEffect(0.90)
                    .overlay { closetGlowOverlay }
                }
                .buttonStyle(.plain)
            }
            .zIndex(closetPhase != .idle ? 1 : 0)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, -4)
        .padding(.horizontal, Spacing.screenHorizontal)
        .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 2))

        // Cart + Trend Magazine row
        bottomCardsRow
            .modifier(ProStaggerModifier(show: proAppeared, isPro: userIsPro, index: 4))
    }

    private var actionCards: some View {
        ActionCard(
            title: L10n.homeDressUp,
            subtitle: L10n.homeDressUpSubtitle,
            icon: userGender == "male" ? "camera.fill" : "square.stack.fill",
            isGolden: userGender == "female",
            customAsset: userGender == "male" ? "male-combin" : "combin",
            creditCost: AppConstants.singleTryOnCost
        ) {
            if RevenueCatManager.shared.isProActive || userCredits > 0 {
                router.push(.dressUp)
            } else {
                showProView = true
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    // MARK: - Weather Card (paper strip — same as old credit strip)

    private var weatherCard: some View {
        VStack(spacing: 6) {
            ZStack {
                // Paper texture background (same as credit strip)
                Image("paper")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 120)
                    .opacity(0.6)

                if weatherTipProvider.hasWeatherData, let temp = weatherTipProvider.temperature {
                    HStack(spacing: 6) {
                        // Weather icon
                        Image(systemName: weatherTipProvider.iconName)
                            .font(.system(size: 18))
                            .foregroundColor(userClosetColorScheme.frameMid)

                        // Temperature
                        Text(temp)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)

                        // Tip text
                        Text(weatherTipProvider.tip)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)

                        Spacer()

                        // Apple Weather attribution
                        if let url = weatherTipProvider.attributionLegalURL {
                            Link(destination: url) {
                                HStack(spacing: 3) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 10))
                                    Text("Weather")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.textSecondary.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                } else if weatherTipProvider.locationDenied {
                    Button {
                        showLocationAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.textSecondary)

                            Text(L10n.weatherLocationDeniedHint)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    // Fallback — no weather data, show tip with title
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.homeTodaysTip)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(.proGold)

                            Text(weatherTipProvider.tip)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .lineLimit(2)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: 64)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Bottom Cards Row (Cart + Trend Magazine)

    private var bottomCardsRow: some View {
        HStack(alignment: .top, spacing: 44) {
            // Cart — sadece resim + başlık
            Button(action: { showCart = true }) {
                VStack(spacing: 10) {
                    Image("basket")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 175, height: 175)

                    Text(L10n.cartTitle)
                        .font(STFont.labelMedium)
                        .foregroundColor(.textPrimary)
                }
            }
            .buttonStyle(.plain)

            // Trend Magazine — kitap kartı + başlık
            Button(action: { router.push(.trendMagazine) }) {
                TrendMagazineCard()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, 8)
    }

    // MARK: - Recent Looks Column (shared)

    private var recentLooksColumn: some View {
        VStack(alignment: .center, spacing: 12) {
            if let looksVM = container.looksViewModel {
                let _ = recentLooksRefresh
                let _ = looksVM.lookImagesVersion
                let loadedImages = Array(looksVM.recentLooks.prefix(3).compactMap { looksVM.lookImage(for: $0.id) })

                if !loadedImages.isEmpty {
                    StackedLooksCards(images: loadedImages, onNavigate: {
                        router.push(.looks)
                    }, compact: userIsPro)
                } else {
                    Button(action: { router.push(.looks) }) {
                        EmptyStackedLooksCards(compact: userIsPro)
                    }
                }
            } else {
                Button(action: { router.push(.looks) }) {
                    EmptyStackedLooksCards(compact: userIsPro)
                }
            }
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Empty Stacked Looks Cards (Placeholder)

private struct EmptyStackedLooksCards: View {
    var compact: Bool = false

    private var photoWidth: CGFloat { compact ? 130 : 145 }
    private var photoHeight: CGFloat { compact ? 158 : 180 }
    private var bottomHeight: CGFloat { compact ? 34 : 40 }
    private var frameHeight: CGFloat { compact ? 220 : 250 }

    var body: some View {
        ZStack {
            // Bottom card (rotated right)
            emptyPolaroidCard()
                .rotationEffect(.degrees(4))
                .offset(x: 6, y: 6)
                .zIndex(0)

            // Middle card (rotated left)
            emptyPolaroidCard()
                .rotationEffect(.degrees(-3))
                .offset(x: -4, y: 3)
                .zIndex(1)

            // Top card (slight right tilt)
            emptyPolaroidCard()
                .rotationEffect(.degrees(1.5))
                .zIndex(2)
        }
        .frame(height: frameHeight)
    }

    private func emptyPolaroidCard() -> some View {
        VStack(spacing: 0) {
            // Empty photo area with placeholder text
            ZStack {
                Rectangle()
                    .fill(Color.bgSecondary.opacity(0.3))
                    .frame(width: photoWidth, height: photoHeight)

                Text(L10n.homeSavedImagesPlaceholder)
                    .font(.system(size: compact ? 10 : 12, weight: .medium))
                    .foregroundColor(.textSecondary.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            // Polaroid bottom
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: photoWidth, height: bottomHeight)

                Text(L10n.homeRecentLooks)
                    .font(compact ? STFont.handwriting : STFont.handwriting)
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .rotationEffect(.degrees(-2))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Stacked Looks Cards Component

private struct StackedLooksCards: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    let images: [UIImage]
    let onNavigate: () -> Void
    var compact: Bool = false
    @State private var showBottomCard = false
    @State private var showMiddleCard = false
    @State private var showTopCard = false
    @State private var fanOut = false

    private var imageWidth: CGFloat { compact ? 118 : 134 }
    private var imageHeight: CGFloat { compact ? 147 : 168 }
    private var bottomHeight: CGFloat { compact ? 34 : 40 }
    private var totalWidth: CGFloat { compact ? 130 : 145 }
    private var frameHeight: CGFloat { compact ? 220 : 250 }

    var body: some View {
        ZStack {
            // Bottom card (rotated right) - First to appear
            if images.count > 2 {
                polaroidCard(image: images[2])
                    .rotationEffect(.degrees(fanOut ? 10 : 4))
                    .offset(x: fanOut ? -30 : 6, y: fanOut ? 10 : 6)
                    .zIndex(0)
                    .opacity(showBottomCard ? 1 : 0)
                    .scaleEffect(showBottomCard ? 1 : 0.8)
                    .offset(y: showBottomCard ? 0 : 20)
            }

            // Middle card (rotated left) - Second to appear
            if images.count > 1 {
                polaroidCard(image: images[1])
                    .rotationEffect(.degrees(fanOut ? -8 : -3))
                    .offset(x: fanOut ? 28 : -4, y: fanOut ? 8 : 3)
                    .zIndex(1)
                    .opacity(showMiddleCard ? 1 : 0)
                    .scaleEffect(showMiddleCard ? 1 : 0.8)
                    .offset(y: showMiddleCard ? 0 : 20)
            }

            // Top card (slight right tilt) - Last to appear
            if images.count > 0 {
                polaroidCard(image: images[0])
                    .rotationEffect(.degrees(fanOut ? -1 : 1.5))
                    .offset(y: fanOut ? -12 : 0)
                    .zIndex(2)
                    .opacity(showTopCard ? 1 : 0)
                    .scaleEffect(fanOut ? 1.03 : (showTopCard ? 1 : 0.8))
                    .offset(y: showTopCard ? 0 : 20)
            }
        }
        .frame(height: frameHeight)
        .onTapGesture {
            guard !fanOut else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                fanOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onNavigate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    fanOut = false
                }
            }
        }
        .onAppear {
            // Stagger animation: bottom → middle → top
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showBottomCard = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showMiddleCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showTopCard = true
                }
            }
        }
    }

    private func polaroidCard(image: UIImage) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .padding(compact ? 4 : 6)

            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: totalWidth, height: bottomHeight)

                Text(L10n.homeRecentLooks)
                    .font(compact ? STFont.handwriting : STFont.handwritingMedium)
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .rotationEffect(.degrees(-2))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
