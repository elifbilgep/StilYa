//
//  TrendMagazineView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 20.02.2026.
//

import SwiftUI
import SafariServices

// MARK: - Trend Data Model

struct TrendCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let items: [TrendItem]
}

struct TrendItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let color: Color? // For color swatches
    let hexCode: String? // For displaying hex
    let articleURL: URL? // Link to fashion article
}

// MARK: - Safari WebView Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(Color.accent)
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Trend Magazine View

struct TrendMagazineView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: Int = 0
    @State private var headerVisible = true
    @State private var selectedArticleURL: URL?

    private var isTurkish: Bool {
        localizationManager.currentLanguage == .turkish
    }

    private let colorHexCodes = ["#722F37", "#6B7B3A", "#B4A7D6", "#C4A36E", "#A9A9A9", "#3E2723"]

    // MARK: - Per-item URLs (TR: Türkçe kaynaklar, EN: İngilizce kaynaklar)

    private var colorURLs: [URL?] {
        let url = isTurkish
            ? URL(string: "https://vogue.com.tr/trend/2025-kis-sezonu-renk-trendleri")
            : URL(string: "https://www.marieclaire.com/fashion/winter-fashion/winter-fashion-color-trends-2026/")
        return Array(repeating: url, count: 6)
    }

    private var pieceURLs: [URL?] {
        isTurkish ? [
            URL(string: "https://www.elle.com.tr/moda/trendler/trenckotla-stilinizi-yukseltecek-kombin-fikirleri"),
            URL(string: "https://vogue.com.tr/trend/kis-stilinde-mega-orguler"),
            URL(string: "https://www.elle.com.tr/moda/trendler/2025-sonbaharkis-pantolon-trendlerinde-one-cikan-6-siluet"),
            URL(string: "https://www.elle.com.tr/moda/trendler/her-sezonun-vazgecilmezi-oversized-blazer-ceketler"),
            URL(string: "https://www.hurriyet.com.tr/kelebek/hurriyet-cumartesi/hacimli-etekler-kabarik-kollar-dantel-dokular-ve-inciler-sanki-19uncu-yuzyildaymisiz-gibi-43107536"),
            URL(string: "https://www.instyle.com.tr/moda/minimal-siluetlere-dinamik-bir-dokunus-puskullu-parcalar/"),
        ] : [
            URL(string: "https://www.whowhatwear.com/fashion/trends/blazer-trends-2026"),
            URL(string: "https://www.stitchfix.com/women/blog/trends-and-occasions/winter-style-guide-2026/"),
            URL(string: "https://editorialist.com/fashion/2026-fashion-trends/"),
            URL(string: "https://www.marieclaire.com/fashion/winter-fashion/winter-fashion-trends-2026/"),
            URL(string: "https://www.whowhatwear.com/fashion/trends/jacket-trends-2026"),
            URL(string: "https://www.whowhatwear.com/fashion/trends/dress-trends-2026"),
        ]
    }

    private var shoeURLs: [URL?] {
        isTurkish ? [
            URL(string: "https://vogue.com.tr/trend/2026-kisinda-tuylu-ayakkabilarin-yukselisi"),
            URL(string: "https://www.elle.com.tr/moda/trendler/2025-sonbaharkisinda-one-cikan-6-cizme-trendi"),
            URL(string: "https://vogue.com.tr/trend/biker-botlar-yaz-aylarinin-vazgecilmezi-oldu"),
            URL(string: "https://www.elle.com.tr/moda/trendler/yeni-trend-radari-binici-cizmeleri"),
        ] : [
            URL(string: "https://www.marieclaire.com/fashion/winter-fashion/winter-boot-trends-2026/"),
            URL(string: "https://graziadaily.co.uk/fashion/shopping/winter-boot-trends-2026/"),
            URL(string: "https://www.marieclaire.com/fashion/winter-fashion/winter-shoe-trends-2026/"),
            URL(string: "https://www.whowhatwear.com/fashion/shoes/boot-trends-2026"),
        ]
    }

    private var accessoryURLs: [URL?] {
        isTurkish ? [
            URL(string: "https://vogue.com.tr/trend/2026-modasinda-basrol-sik-kucuk-sapkalarda"),
            URL(string: "https://www.instyle.com.tr/moda/retro-kodlar-modern-tavir-sezonun-guclu-aksesuarlari/"),
            URL(string: "https://www.elle.com.tr/moda/trendler/kis-stilinize-fark-katacak-statement-kupeler"),
            URL(string: "https://vogue.com.tr/trend/2026-yilinda-her-yerde-goreceginiz-7-canta-trendi"),
        ] : [
            URL(string: "https://www.whowhatwear.com/fashion/trends/triangle-scarf-trend-winter-2026"),
            URL(string: "https://www.marieclaire.com/fashion/jewelry-trends-2026/"),
            URL(string: "https://www.marieclaire.com/fashion/winter-fashion/winter-bag-trends-2026/"),
            URL(string: "https://www.whowhatwear.com/fashion/shopping/oversize-sunglasses-2026"),
        ]
    }

    private var categories: [TrendCategory] {
        [
            TrendCategory(
                icon: "paintpalette.fill",
                title: L10n.trendColorsTitle,
                subtitle: L10n.trendColorsSubtitle,
                items: [
                    TrendItem(name: L10n.trendColorBurgundy, description: L10n.trendColorBurgundyDesc, color: Color(hex: colorHexCodes[0]), hexCode: colorHexCodes[0], articleURL: colorURLs[0]),
                    TrendItem(name: L10n.trendColorOlive, description: L10n.trendColorOliveDesc, color: Color(hex: colorHexCodes[1]), hexCode: colorHexCodes[1], articleURL: colorURLs[1]),
                    TrendItem(name: L10n.trendColorLavender, description: L10n.trendColorLavenderDesc, color: Color(hex: colorHexCodes[2]), hexCode: colorHexCodes[2], articleURL: colorURLs[2]),
                    TrendItem(name: L10n.trendColorCamel, description: L10n.trendColorCamelDesc, color: Color(hex: colorHexCodes[3]), hexCode: colorHexCodes[3], articleURL: colorURLs[3]),
                    TrendItem(name: L10n.trendColorPebbleGray, description: L10n.trendColorPebbleGrayDesc, color: Color(hex: colorHexCodes[4]), hexCode: colorHexCodes[4], articleURL: colorURLs[4]),
                    TrendItem(name: L10n.trendColorChocolate, description: L10n.trendColorChocolateDesc, color: Color(hex: colorHexCodes[5]), hexCode: colorHexCodes[5], articleURL: colorURLs[5]),
                ]
            ),
            TrendCategory(
                icon: "tshirt.fill",
                title: L10n.trendPiecesTitle,
                subtitle: L10n.trendPiecesSubtitle,
                items: [
                    TrendItem(name: L10n.trendPieceOversizedBlazer, description: L10n.trendPieceOversizedBlazerDesc, color: nil, hexCode: nil, articleURL: pieceURLs[0]),
                    TrendItem(name: L10n.trendPiecePoloSweater, description: L10n.trendPiecePoloSweaterDesc, color: nil, hexCode: nil, articleURL: pieceURLs[1]),
                    TrendItem(name: L10n.trendPiecePencilSkirt, description: L10n.trendPiecePencilSkirtDesc, color: nil, hexCode: nil, articleURL: pieceURLs[2]),
                    TrendItem(name: L10n.trendPieceLeatherPieces, description: L10n.trendPieceLeatherPiecesDesc, color: nil, hexCode: nil, articleURL: pieceURLs[3]),
                    TrendItem(name: L10n.trendPieceCroppedJacket, description: L10n.trendPieceCroppedJacketDesc, color: nil, hexCode: nil, articleURL: pieceURLs[4]),
                    TrendItem(name: L10n.trendPieceMiniDress, description: L10n.trendPieceMiniDressDesc, color: nil, hexCode: nil, articleURL: pieceURLs[5]),
                ]
            ),
            TrendCategory(
                icon: "shoe.fill",
                title: L10n.trendShoesTitle,
                subtitle: L10n.trendShoesSubtitle,
                items: [
                    TrendItem(name: L10n.trendShoeCowboyBoots, description: L10n.trendShoeCowboyBootsDesc, color: nil, hexCode: nil, articleURL: shoeURLs[0]),
                    TrendItem(name: L10n.trendShoeSlouchyBoots, description: L10n.trendShoeSlouchyBootsDesc, color: nil, hexCode: nil, articleURL: shoeURLs[1]),
                    TrendItem(name: L10n.trendShoeBalletFlats, description: L10n.trendShoeBalletFlatsDesc, color: nil, hexCode: nil, articleURL: shoeURLs[2]),
                    TrendItem(name: L10n.trendShoeKneeHighBoots, description: L10n.trendShoeKneeHighBootsDesc, color: nil, hexCode: nil, articleURL: shoeURLs[3]),
                ]
            ),
            TrendCategory(
                icon: "sparkles",
                title: L10n.trendAccessoriesTitle,
                subtitle: L10n.trendAccessoriesSubtitle,
                items: [
                    TrendItem(name: L10n.trendAccessoryChunkyScarf, description: L10n.trendAccessoryChunkyScarfDesc, color: nil, hexCode: nil, articleURL: accessoryURLs[0]),
                    TrendItem(name: L10n.trendAccessoryGoldJewelry, description: L10n.trendAccessoryGoldJewelryDesc, color: nil, hexCode: nil, articleURL: accessoryURLs[1]),
                    TrendItem(name: L10n.trendAccessoryStructuredBag, description: L10n.trendAccessoryStructuredBagDesc, color: nil, hexCode: nil, articleURL: accessoryURLs[2]),
                    TrendItem(name: L10n.trendAccessoryOversizedSunglasses, description: L10n.trendAccessoryOversizedSunglassesDesc, color: nil, hexCode: nil, articleURL: accessoryURLs[3]),
                ]
            ),
        ]
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Magazine Header
                    magazineHeader
                        .padding(.bottom, 24)

                    // Category Tabs
                    categoryTabs
                        .padding(.bottom, 20)

                    // Selected Category Content
                    categoryContent
                        .padding(.bottom, 40)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("STILYA")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .tracking(4)
                    .foregroundColor(.textSecondary)
            }
        }
        .sheet(item: $selectedArticleURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        // Animation removed — content shows instantly to avoid re-play on navigation back
    }

    // MARK: - Magazine Header

    private var magazineHeader: some View {
        ZStack {
            // Koyu arka plan
            Color(hex: "#1A1A1A")

            VStack(spacing: 0) {
                Spacer()

                // Üst dekoratif çizgi
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 50, height: 0.5)

                Spacer()
                    .frame(height: 24)

                // Ana başlık
                Text(L10n.trendMagazineTitle)
                    .font(STFont.displayHero)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()
                    .frame(height: 16)

                // Yıl
                Text(verbatim: "— \(Calendar.current.component(.year, from: Date())) —")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
                    .frame(height: 20)

                // Subtitle
                Text(L10n.trendMagazineSubtitle)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories.indices, id: \.self) { index in
                    let category = categories[index]
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = index
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                            Text(category.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedCategory == index ? Color.accent : Color.bgSecondary)
                        )
                        .foregroundColor(selectedCategory == index ? .white : .textPrimary)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    // MARK: - Category Content

    private var categoryContent: some View {
        let category = categories[selectedCategory]

        return VStack(alignment: .leading, spacing: 20) {
            // Category header
            VStack(alignment: .leading, spacing: 6) {
                Text(category.title)
                    .font(STFont.displaySmall)
                    .foregroundColor(.textPrimary)

                Text(category.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            // Items
            if category.items.first?.color != nil {
                // Color category — special grid layout
                colorGrid(items: category.items)
            } else {
                // Text-based items — magazine editorial style with article links
                editorialList(items: category.items)
            }
        }
        .id(selectedCategory) // Force rebuild on category change
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Color Grid

    private func colorGrid(items: [TrendItem]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(items) { item in
                colorCard(item: item)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    private func colorCard(item: TrendItem) -> some View {
        Button(action: {
            if let url = item.articleURL {
                selectedArticleURL = url
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Color swatch
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.color ?? Color.gray)
                    .frame(height: 80)
                    .overlay(alignment: .bottomTrailing) {
                        if let hex = item.hexCode {
                            Text(hex)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(isLightColor(hex: hex) ? .black.opacity(0.5) : .white.opacity(0.8))
                                .padding(6)
                        }
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Text(item.description)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(1)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Editorial List

    private func editorialList(items: [TrendItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                editorialRow(item: item, index: index + 1)

                if index < items.count - 1 {
                    Divider()
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
        }
    }

    private func editorialRow(item: TrendItem, index: Int) -> some View {
        Button(action: {
            if let url = item.articleURL {
                selectedArticleURL = url
            }
        }) {
            HStack(alignment: .center, spacing: 14) {
                // Index number — magazine style
                Text(String(format: "%02d", index))
                    .font(STFont.displayMedium)
                    .foregroundColor(.accent.opacity(0.15))
                    .frame(width: 36, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Text(item.description)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    // Source hint
                    if item.articleURL != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                            Text(L10n.trendReadMore)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accent.opacity(0.5))
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Chevron
                if item.articleURL != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary.opacity(0.4))
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func isLightColor(hex: String) -> Bool {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6, let rgb = UInt64(hexStr, radix: 16) else { return false }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6
    }
}

// MARK: - URL Identifiable Extension

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    NavigationStack {
        TrendMagazineView()
    }
}
