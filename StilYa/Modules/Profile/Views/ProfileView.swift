//
//  ProfileView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI
import PhotosUI
import RevenueCat
import Combine

struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var viewModel: ProfileViewModel?
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var showModelPhotoSheet = false
    @State private var showLogoutAlert = false
    @State private var showEditNameSheet = false
    #if DEBUG
    @State private var showDebugLogs = false
    #endif
    @State private var toast: Toast?
    @State private var navigateToSettings = false
    @State private var showProView = false
    @State private var showDataProtection = false
    @State private var showAccountLinking = false

    private var isAnonymous: Bool {
        // Access currentUser to create SwiftUI dependency on this stored property
        let _ = container.authViewModel?.currentUser
        return container.authViewModel?.isAnonymous ?? false
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)

                    Text(L10n.profileTitle)
                        .font(STFont.displayPage)
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: 24)

                    // Compact Profile Card (profile photo + model photo in one)
                    if let viewModel = viewModel {
                        CompactProfileCard(
                            viewModel: viewModel,
                            selectedProfileImage: $selectedProfileImage,
                            onModelPhotoTap: { showModelPhotoSheet = true },
                            onNameTap: { showEditNameSheet = true }
                        )
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }

                    Spacer().frame(height: 20)

                    // Membership & Credit Card
                    if let viewModel = viewModel {
                        MembershipCard(viewModel: viewModel, showProView: $showProView)
                            .padding(.horizontal, Spacing.screenHorizontal)
                    }

                    Spacer().frame(height: 24)

                    // Anonymous banner
                    if isAnonymous {
                        anonymousBanner
                            .padding(.horizontal, Spacing.screenHorizontal)
                        Spacer().frame(height: 16)
                    }

                    // Profile Menu
                    VStack(spacing: 12) {
                        ProfileMenuItem(icon: "shield.checkered", title: L10n.profileDataProtection) {
                            showDataProtection = true
                        }

                        ProfileMenuItem(icon: "gearshape.fill", title: L10n.profileSettings) {
                            navigateToSettings = true
                        }

                        ProfileMenuItem(icon: "rectangle.portrait.and.arrow.right", title: L10n.profileSignOut) {
                            showLogoutAlert = true
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: 32)

                    // User ID (debug only)
                    #if DEBUG
                    if let userId = viewModel?.currentUser?.id {
                        UserIdFooter(userId: userId, onSecretTap: {
                            showDebugLogs = true
                        })
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }
                    #endif

                    Spacer().frame(height: 40)
                }
            }
            .id(localizationManager.currentLanguage)
        }
        .sheet(isPresented: $showModelPhotoSheet, onDismiss: {
            Task {
                await viewModel?.loadModelPhoto()
            }
        }) {
            ModelPhotoSheet()
                .preferredColorScheme(.light)
        }
        #if DEBUG
        .sheet(isPresented: $showDebugLogs) {
            DebugLogView(onClose: { showDebugLogs = false })
        }
        #endif
        .sheet(isPresented: $showEditNameSheet) {
            if let viewModel = viewModel {
                EditNameSheet(viewModel: viewModel, toast: $toast)
                    .preferredColorScheme(.light)
            }
        }
        .sheet(isPresented: $showProView) {
            ProView()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showDataProtection) {
            DataProtectionSheet()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showAccountLinking) {
            if let authVM = container.authViewModel {
                AccountLinkingSheet(authViewModel: authVM)
                    .preferredColorScheme(.light)
            }
        }
        .fullScreenCover(isPresented: $navigateToSettings) {
            if let viewModel = viewModel {
                SettingsView(viewModel: viewModel)
                    .environmentObject(container)
                    .environmentObject(localizationManager)
                    .preferredColorScheme(.light)
            }
        }
        .toast($toast)
        .alert(L10n.profileSignOutTitle, isPresented: $showLogoutAlert) {
            Button(L10n.commonCancel, role: .cancel) {}
            Button(L10n.profileSignOutTitle, role: .destructive) {
                handleLogout()
            }
        } message: {
            Text(L10n.profileSignOutConfirm)
        }
        .task {
            // Initialize ViewModel
            let vm = ProfileViewModel(
                authRepository: container.authRepository,
                userRepository: container.userRepository,
                storageRepository: container.storageRepository,
                lookRepository: container.lookRepository,
                referralRepository: container.referralRepository
            )
            viewModel = vm

            // Load photos and stats in parallel
            async let photos: () = vm.loadProfilePhoto()
            async let model: () = vm.loadModelPhoto()
            async let stats: () = vm.loadStats()
            _ = await (photos, model, stats)
        }
        .onAppear {
            if let vm = viewModel {
                Task { await vm.refreshUser() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .modelPhotoDidUpdate)) { _ in
            if let vm = viewModel {
                Task { await vm.loadModelPhoto() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .creditsDidUpdate)) { _ in
            if let vm = viewModel {
                Task { await vm.refreshUser() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .proStatusDidChange)) { _ in
            if let vm = viewModel {
                Task { await vm.refreshUser() }
            }
        }
    }

    // MARK: - Anonymous Banner
    private var anonymousBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.proGold.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(.proGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.profileAnonymousTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text(L10n.profileAnonymousSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Button(action: { showAccountLinking = true }) {
                    Text(L10n.profileLinkAccount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.proGold)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.proGold.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.proGold.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func handleLogout() {
        guard let viewModel = viewModel else { return }

        Task {
            do {
                try await viewModel.logout()
                // Clear cached ViewModels (eski hesap verileri)
                await MainActor.run {
                    container.resetOnLogout()
                    container.onLogout?()
                }
            } catch {
                #if DEBUG
                print("❌ [Profile] Logout failed: \(error)")
                #endif
                toast = Toast(type: .error, message: L10n.profileSignOutFailed)
            }
        }
    }
}

// MARK: - Compact Profile Card (profile photo + model photo + info)
struct CompactProfileCard: View {
    @Bindable var viewModel: ProfileViewModel
    @Binding var selectedProfileImage: PhotosPickerItem?
    var onModelPhotoTap: () -> Void
    var onNameTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Left: Profile Photo
            PhotosPicker(selection: $selectedProfileImage, matching: .images) {
                ProfileAvatar(
                    image: viewModel.profileImage,
                    size: 56,
                    isLoading: viewModel.isLoading,
                    showCameraBadge: true
                )
            }
            .onChange(of: selectedProfileImage) { _, newValue in
                Task {
                    await viewModel.uploadProfilePhoto(newValue)
                }
            }
            .disabled(viewModel.isLoading)

            // Center: User info (tappable to edit name)
            Button(action: onNameTap) {
                VStack(alignment: .leading, spacing: 4) {
                    if let user = viewModel.currentUser {
                        HStack(spacing: 4) {
                            Text(user.displayName?.isEmpty == false ? user.displayName! : L10n.profileUser)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)

                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(.textSecondary.opacity(0.6))
                        }

                        if let email = user.email, !email.isEmpty {
                            Text(email)
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(L10n.profileLoadingUser)
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Right: Model Photo (mini preview with edit badge)
            Button(action: onModelPhotoTap) {
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.bgPrimary)
                            .frame(width: 56, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.border, lineWidth: 1)
                            )

                        if viewModel.isLoadingModelImage {
                            ProgressView()
                                .tint(.textSecondary)
                                .frame(width: 56, height: 56)
                        } else if let modelImage = viewModel.modelImage {
                            Image(uiImage: modelImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(systemName: "person.and.background.dotted")
                                .font(.system(size: 20))
                                .foregroundColor(.textSecondary.opacity(0.4))
                                .frame(width: 56, height: 56)
                        }

                        // Edit badge
                        Circle()
                            .fill(Color.proGold)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 4, y: -4)
                    }

                    Text(L10n.profileReference)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bgSecondary)
        )
    }
}

// MARK: - Profile Menu Item
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.bgSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stats Section
struct ProfileStatsSection: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "sparkles",
                value: "\(viewModel.totalLooks)",
                label: L10n.profileTrials
            )

            StatCard(
                icon: "heart.fill",
                value: "\(viewModel.favoriteLooks)",
                label: L10n.profileFavorites
            )

            StatCard(
                icon: "flame.fill",
                value: "\(viewModel.currentUser?.totalCreditsUsed ?? 0)",
                label: L10n.profileCredits
            )
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.proGold)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgSecondary)
        )
    }
}

// MARK: - Membership Card
struct MembershipCard: View {
    @Bindable var viewModel: ProfileViewModel
    @Binding var showProView: Bool
    @State private var showCreditSheet = false

    private var user: User? { viewModel.currentUser }
    private var isPro: Bool { RevenueCatManager.shared.isProActive }

    private var memberSince: String {
        guard let date = user?.createdAt else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = LocalizationManager.shared.currentLanguage.locale
        return formatter.string(from: date)
    }

    private var renewalText: String? {
        let rcExpiry = RevenueCatManager.shared.customerInfo?
            .entitlements[RevenueCatManager.proEntitlementID]?.expirationDate
        let expiryDate = rcExpiry ?? user?.subscriptionExpiryDate
        guard let expiryDate, expiryDate > Date() else { return nil }
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: expiryDate)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        if days > 0 {
            return "\(days)g \(hours)sa"
        } else if hours > 0 {
            return "\(hours)sa \(minutes)dk"
        } else {
            return "\(minutes)dk"
        }
    }

    private var planDisplayName: String {
        guard let plan = user?.subscriptionPlan else { return "" }
        return plan == "weekly" ? L10n.proWeekly : L10n.proMonthly
    }

    // Pro tries
    private var triesUsed: Int {
        let max = user?.proCreditsMax ?? AppConstants.proWeeklyCredits
        let remaining = user?.proCredits ?? 0
        return max - remaining
    }

    private var triesMax: Int {
        user?.proCreditsMax ?? AppConstants.proWeeklyCredits
    }

    private var triesRemaining: Int {
        user?.proCredits ?? 0
    }

    private var triesProgress: Double {
        guard triesMax > 0 else { return 0 }
        return Double(triesRemaining) / Double(triesMax)
    }

    var body: some View {
        Group {
            if isPro {
                proCard
            } else {
                freeCard
            }
        }
        .sheet(isPresented: $showCreditSheet) {
            HomeCreditSheet()
        }
    }

    // MARK: - Pro Card

    private var proCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.proGold)
                Text(L10n.profileProMember)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.proGold)
                if !planDisplayName.isEmpty {
                    Text("— \(planDisplayName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.proGold.opacity(0.7))
                }
                Spacer()
            }

            // Tries progress
            HStack(spacing: 16) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.proGold.opacity(0.15), lineWidth: 6)
                        .frame(width: 64, height: 64)

                    Circle()
                        .trim(from: 0, to: triesProgress)
                        .stroke(Color.proGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: triesProgress)

                    VStack(spacing: 0) {
                        Text("\(triesRemaining)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.proGold)
                        Text("/\(triesMax)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.proGold.opacity(0.6))
                    }
                }

                // Info column
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.profileProCredits)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    if let renewal = renewalText {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                            Text(renewal)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.textSecondary)
                    }

                    Text("\(L10n.profileMemberSince) \(memberSince)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary.opacity(0.7))
                }

                Spacer()
            }

            // Kredi Ekle button
            Button(action: { showCreditSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text(L10n.profileBuyCredits)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.proGold.opacity(0.15))
                .foregroundColor(.proGold)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.proGoldLight)
        )
    }

    // MARK: - Free Card

    private var freeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textPrimary)
                Text(L10n.profileFreeMember)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            // Kredi + yenilenme bilgisi
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.profileRemainingCredits)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Text(L10n.profileFreeCreditsHint)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("\(user?.totalAvailableCredits ?? 0)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.accent)
            }

            HStack {
                Text(L10n.profileMemberSince)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(memberSince)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }

            Button(action: { showProView = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text(L10n.proUpgrade)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.proGold)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bgSecondary)
        )
    }
}

// MARK: - Referral Sheet

struct ReferralSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var referralCode: String = ""
    @State private var isLoading = false
    @State private var showShareSheet = false
    @State private var codeCopied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.proGold)
                    .padding(.top, 32)

                Text(L10n.profileInviteTitle)
                    .font(STFont.displayTitle)
                    .foregroundColor(.textPrimary)

                Text(L10n.profileInviteDescription(AppConstants.referralBonusCredits))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        Text(L10n.profileYourCode)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)

                        Text(referralCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.bgSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.proGold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .onTapGesture {
                                UIPasteboard.general.string = referralCode
                                codeCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    codeCopied = false
                                }
                            }

                        if codeCopied {
                            Text(L10n.profileCodeCopied)
                                .font(.system(size: 12))
                                .foregroundColor(.success)
                        }
                    }
                }

                if let user = viewModel.currentUser {
                    HStack {
                        Text(L10n.profileInvitedCount)
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("\(user.referralCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                        Text(L10n.profileShareCode)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accent)
                    )
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.commonClose) { dismiss() }
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .shareSheet(isPresented: $showShareSheet, items: ShareableContent.referralCode(referralCode))
        .task {
            isLoading = true
            let code = await viewModel.getOrGenerateReferralCode()
            referralCode = code ?? L10n.profileCodeError
            isLoading = false
        }
    }
}

// MARK: - Feedback Type
enum FeedbackType: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case message = "message"

    var title: String {
        switch self {
        case .bug: return L10n.profileFeedbackTypeBug
        case .feature: return L10n.profileFeedbackTypeFeature
        case .message: return L10n.profileFeedbackTypeMessage
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .feature: return "lightbulb.fill"
        case .message: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .bug: return .error
        case .feature: return .proGold
        case .message: return Color(hex: "#E87FA0")
        }
    }

    var placeholder: String {
        switch self {
        case .bug: return L10n.profileFeedbackPlaceholderBug
        case .feature: return L10n.profileFeedbackPlaceholderFeature
        case .message: return L10n.profileFeedbackPlaceholderMessage
        }
    }
}

// MARK: - Feedback Sheet
struct FeedbackSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var feedbackText: String = ""
    @State private var contactEmail: String = ""
    @State private var selectedType: FeedbackType? = nil
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.proGold)
                        .padding(.top, 32)

                    Text(L10n.profileFeedbackTitle)
                        .font(STFont.displayTitle)
                        .foregroundColor(.textPrimary)

                    Text(L10n.profileFeedbackSelectType)
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)

                    // Feedback type selector
                    HStack(spacing: 12) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            feedbackTypeCard(type)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    if let type = selectedType {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $feedbackText)
                                    .frame(minHeight: 150)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)

                                if feedbackText.isEmpty {
                                    Text(type.placeholder)
                                        .font(.system(size: 15))
                                        .foregroundColor(.textSecondary.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.bgSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.profileFeedbackEmail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSecondary)

                        TextField("", text: $contactEmail, prompt: Text(L10n.profileFeedbackEmailPlaceholder).foregroundColor(.textSecondary))
                            .font(.system(size: 15))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.bgSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer(minLength: 24)

                    Button(action: {
                        submitFeedback()
                    }) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                Text(L10n.profileSend)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canSubmit ? Color.accent : Color.accent.opacity(0.4))
                        )
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.commonClose) { dismiss() }
                        .foregroundColor(.textPrimary)
                }
            }
            .alert(L10n.profileFeedbackThanks, isPresented: $showSuccess) {
                Button(L10n.commonOk) { dismiss() }
            } message: {
                Text(L10n.profileFeedbackSuccess)
            }
            .onAppear {
                contactEmail = viewModel.currentUser?.email ?? ""
            }
        }
    }

    private var canSubmit: Bool {
        selectedType != nil && !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func feedbackTypeCard(_ type: FeedbackType) -> some View {
        let isSelected = selectedType == type
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedType = type
                feedbackText = ""
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : type.color)

                Text(type.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color : Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? type.color : Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var deviceInfoFooter: some View {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        return VStack(spacing: 4) {
            Text(L10n.profileFeedbackDeviceInfo)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)

            Text("\(device.model) · \(device.systemName) \(device.systemVersion) · v\(appVersion) (\(buildNumber))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.bgSecondary.opacity(0.5))
        )
    }

    private func submitFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let type = selectedType else { return }

        isSubmitting = true
        let email = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await viewModel.submitFeedback(
                    message: trimmed,
                    type: type.rawValue,
                    contactEmail: email.isEmpty ? nil : email
                )
                isSubmitting = false
                showSuccess = true
            } catch {
                #if DEBUG
                print("Feedback gonderme hatasi: \(error)")
                #endif
                isSubmitting = false
            }
        }
    }
}

// MARK: - Edit Name Sheet
struct EditNameSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Binding var toast: Toast?
    @Environment(\.dismiss) var dismiss
    @State private var newName: String = ""
    @State private var isLoading = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.proGold)
                    .padding(.top, 32)

                Text(L10n.profileEditName)
                    .font(STFont.displayTitle)
                    .foregroundColor(.textPrimary)

                Text(L10n.profileEditNameDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.profileName)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)

                    TextField("", text: $newName, prompt: Text(L10n.profileFullName).foregroundColor(.textSecondary))
                        .font(.system(size: 16))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.border, lineWidth: 1)
                                )
                        )
                        .focused($isNameFieldFocused)
                        .disabled(isLoading)
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer()

                Button(action: {
                    Task {
                        await updateName()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16))
                            Text(L10n.commonSave)
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accent.opacity(0.5) : Color.accent)
                    )
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.commonClose) { dismiss() }
                        .foregroundColor(.textPrimary)
                        .disabled(isLoading)
                }
            }
        }
        .onAppear {
            newName = viewModel.currentUser?.displayName ?? ""
            isNameFieldFocused = true
        }
    }

    @MainActor
    private func updateName() async {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true

        do {
            try await viewModel.updateDisplayName(trimmedName)
            toast = Toast(type: .success, message: L10n.profileNameUpdated)
            dismiss()
        } catch {
            #if DEBUG
            print("❌ [EditNameSheet] Error updating name: \(error)")
            #endif
            toast = Toast(type: .error, message: L10n.profileNameUpdateFailed)
        }

        isLoading = false
    }
}

// MARK: - Data Protection Sheet

struct DataProtectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header icon
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.success)
                        .padding(.top, 8)

                    Text(L10n.profileDataProtectionTitle)
                        .font(STFont.displaySection)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 16) {
                        dataProtectionRow(
                            icon: "lock.fill",
                            color: .accent,
                            title: L10n.profileDataProtectionEncryption,
                            description: L10n.profileDataProtectionEncryptionDesc
                        )

                        dataProtectionRow(
                            icon: "eye.slash.fill",
                            color: .error,
                            title: L10n.profileDataProtectionNoThirdParty,
                            description: L10n.profileDataProtectionNoThirdPartyDesc
                        )

                        dataProtectionRow(
                            icon: "cloud.fill",
                            color: .proGold,
                            title: L10n.profileDataProtectionSecureStorage,
                            description: L10n.profileDataProtectionSecureStorageDesc
                        )

                        dataProtectionRow(
                            icon: "trash.fill",
                            color: .warning,
                            title: L10n.profileDataProtectionDeleteAnytime,
                            description: L10n.profileDataProtectionDeleteAnytimeDesc
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, 40)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.commonClose) { dismiss() }
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }

    private func dataProtectionRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.bgSecondary)
        )
    }
}

// MARK: - User ID Footer (for support)
struct UserIdFooter: View {
    let userId: String
    var onSecretTap: (() -> Void)?
    @State private var copied = false
    @State private var secretTapCount = 0

    var body: some View {
        VStack(spacing: 6) {
            Text(L10n.profileUserId)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary.opacity(0.5))
                .onTapGesture {
                    secretTapCount += 1
                    if secretTapCount >= 5 {
                        secretTapCount = 0
                        HapticManager.shared.medium()
                        onSecretTap?()
                    }
                }

            HStack(spacing: 8) {
                Text(userId)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textSecondary.opacity(0.6))
                    .lineLimit(1)

                Button {
                    UIPasteboard.general.string = userId
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(copied ? .success : .textSecondary.opacity(0.5))
                }
            }

            if copied {
                Text(L10n.commonCopied)
                    .font(.system(size: 10))
                    .foregroundColor(.success)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}

#Preview {
    ProfileView()
}
