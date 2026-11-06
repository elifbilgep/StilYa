//
//  TrendCollectionsView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//

import SwiftUI

struct TrendCollectionsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager
    @StateObject private var viewModel = TrendsViewModel()
    @State private var selectedCollection: TrendCollection?
    @State private var showMagazine = false
    @State private var showFavorites = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                magazineButton

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.accent)
                        .padding(.top, 60)
                } else if viewModel.collections.isEmpty {
                    emptyState
                } else {
                    // "For You" section
                    if viewModel.hasForYouSection && viewModel.selectedCategory == nil {
                        forYouSection
                    }

                    // Category filter
                    if !viewModel.categories.isEmpty {
                        categoryFilters
                    }

                    // Collections grid
                    if viewModel.filteredCollections.isEmpty {
                        emptyState
                    } else {
                        collectionsGrid
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.trendsTitle)
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.accent)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFavorites = true }) {
                    Image(systemName: viewModel.favoriteImageURLs.isEmpty ? "heart" : "heart.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.favoriteImageURLs.isEmpty ? .accent : .error)
                }
            }
        }
        .onAppear {
            Task {
                let user = try? await container.userRepository.getUser(
                    id: container.authRepository.getCurrentUserId() ?? ""
                )
                viewModel.userStylePreferences = user?.stylePreferences ?? []
                await viewModel.loadCollections(gender: user?.gender)
            }
        }
        .fullScreenCover(item: $selectedCollection) { collection in
            TrendCollectionDetailView(collection: collection, viewModel: viewModel)
                .environmentObject(container)
                .environmentObject(router)
                .environmentObject(localizationManager)
        }
        .sheet(isPresented: $showFavorites) {
            TrendFavoritesSheet(viewModel: viewModel)
                .environmentObject(container)
                .environmentObject(router)
                .environmentObject(localizationManager)
        }
        .sheet(isPresented: $showMagazine) {
            NavigationStack {
                TrendMagazineView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { showMagazine = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.accent)
                            }
                        }
                    }
            }
            .environmentObject(localizationManager)
        }
    }

    // MARK: - For You Section

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.proGold)
                Text(L10n.trendsForYou)
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.accent)
            }
            .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.forYouCollections) { collection in
                        forYouCard(collection)
                    }
                }
            }

            Divider()
                .background(Color.border)
                .padding(.top, 4)
        }
    }

    private func forYouCard(_ collection: TrendCollection) -> some View {
        Button(action: { selectedCollection = collection }) {
            VStack(alignment: .leading, spacing: 6) {
                if let firstUrl = collection.imageUrls.first {
                    ZStack(alignment: .topTrailing) {
                        RetryImageView(url: firstUrl)
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(width: 140)
                            .clipped()
                            .cornerRadius(12)

                        // Heart on first image
                        if viewModel.isFavorite(firstUrl) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.error)
                                .padding(6)
                        }
                    }
                }

                Text(localizedCategory(collection.category))
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(.accent.opacity(0.6))
                    .frame(width: 140, alignment: .leading)
            }
        }
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryPill(title: L10n.trendsAllCategories, isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }

                ForEach(viewModel.categories, id: \.self) { cat in
                    categoryPill(
                        title: localizedCategory(cat),
                        isSelected: viewModel.selectedCategory == cat
                    ) {
                        viewModel.selectedCategory = cat
                    }
                }
            }
        }
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(isSelected ? .white : .accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accent : Color.bgSecondary)
                .cornerRadius(20)
        }
    }

    // MARK: - Collections Grid

    private var collectionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(viewModel.filteredCollections) { collection in
                collectionCard(collection)
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentItem: collection) }
                    }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private func collectionCard(_ collection: TrendCollection) -> some View {
        Button(action: { selectedCollection = collection }) {
            VStack(alignment: .leading, spacing: 0) {
                if let firstUrl = collection.imageUrls.first {
                    ZStack(alignment: .topTrailing) {
                        RetryImageView(url: firstUrl)
                            .aspectRatio(3/4, contentMode: .fit)
                            .clipped()

                        // Favorite heart badge
                        let favCount = collection.imageUrls.filter { viewModel.isFavorite($0) }.count
                        if favCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                if favCount > 1 {
                                    Text("\(favCount)")
                                        .font(.custom("DMSans-SemiBold", size: 10))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.error.opacity(0.85))
                            .cornerRadius(10)
                            .padding(8)
                        }
                    }
                } else {
                    imagePlaceholder
                }

                // Info bar at bottom
                HStack(spacing: 6) {
                    Text(localizedCategory(collection.category))
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(.accent.opacity(0.7))

                    Spacer()

                    Text("\(collection.imageUrls.count)")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.accent.opacity(0.4))

                    Image(systemName: "photo")
                        .font(.system(size: 10))
                        .foregroundColor(.accent.opacity(0.3))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.bgPrimary)
            }
            .cornerRadius(14)
            .clipped()
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color.bgSecondary)
            .aspectRatio(3/4, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.accent.opacity(0.2))
            )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(.accent.opacity(0.3))
            Text(L10n.trendsEmpty)
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundColor(.accent.opacity(0.5))
        }
        .padding(.top, 60)
    }

    // MARK: - Magazine Button

    private var magazineButton: some View {
        ActionCard(
            title: L10n.trendMagazineTitle,
            subtitle: L10n.trendMagazineSubtitle,
            icon: "camera.fill",
            isGolden: false
        ) {
            showMagazine = true
        }
    }

    // MARK: - Helpers

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

// MARK: - Favorites Sheet

struct TrendFavoritesSheet: View {
    @ObservedObject var viewModel: TrendsViewModel
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCollection: TrendCollection?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                if viewModel.favoriteImageURLs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart")
                            .font(.system(size: 40))
                            .foregroundColor(.accent.opacity(0.25))
                        Text(L10n.trendsFavoritesEmpty)
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.accent.opacity(0.6))
                        Text(L10n.trendsFavoritesEmptyDesc)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.accent.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            ForEach(viewModel.favoriteOutfits, id: \.url) { item in
                                favoriteCard(url: item.url)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.trendsFavorites)
                        .font(.custom("InstrumentSerif-Regular", size: 20))
                        .foregroundColor(.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accent)
                    }
                }
            }
        }
    }

    private func favoriteCard(url: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RetryImageView(url: url)
                .aspectRatio(3/4, contentMode: .fit)

            // Overlay actions
            HStack(spacing: 6) {
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        router.push(.dressUp)
                    }
                }) {
                    Image(systemName: "tshirt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accent.opacity(0.8))
                        .clipShape(Circle())
                }

                Button(action: { viewModel.toggleFavorite(url) }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.error.opacity(0.85))
                        .clipShape(Circle())
                }
            }
            .padding(8)
        }
        .cornerRadius(14)
        .clipped()
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}
