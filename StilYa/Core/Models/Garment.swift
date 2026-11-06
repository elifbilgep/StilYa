//
//  Garment.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation

// MARK: - Garment Type
enum GarmentType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Main Garments (try-on edilebilir kıyafetler)
    case top = "tops"           // Üst (tişört, gömlek, kazak)
    case bottom = "bottoms"     // Alt (pantolon, etek, şort)
    case dress = "one-pieces"   // Elbise (tek parça)
    case jacket = "jackets"     // Dış giyim (ceket, hırka, mont, blazer)
    // Accessories (kombin için aksesuarlar)
    case glasses = "glasses"          // Gözlük (şeffaf cam)
    case sunglasses = "sunglasses"    // Güneş Gözlüğü (koyu cam)
    case hat = "hat"                  // Şapka
    case scarf = "scarf"              // Atkı
    case shoes = "shoes"              // Ayakkabı
    case bag = "bag"                  // Çanta
    case socks = "socks"              // Çorap

    var displayName: String {
        switch self {
        case .top: return L10n.garmentTop
        case .bottom: return L10n.garmentBottom
        case .dress: return L10n.garmentDress
        case .jacket: return L10n.garmentJacket
        case .glasses: return L10n.garmentGlasses
        case .sunglasses: return L10n.garmentSunglasses
        case .hat: return L10n.garmentHat
        case .scarf: return L10n.garmentScarf
        case .shoes: return L10n.garmentShoes
        case .bag: return L10n.garmentBag
        case .socks: return L10n.garmentSocks
        }
    }

    /// Short text label for garment type cards (replaces SF Symbol icons)
    var shortLabel: String {
        switch self {
        case .top: return L10n.garmentTop
        case .bottom: return L10n.garmentBottom
        case .dress: return L10n.garmentDress
        case .jacket: return L10n.garmentJacket
        case .shoes: return L10n.garmentShoes
        case .glasses: return L10n.garmentGlasses
        case .sunglasses: return L10n.garmentSunglasses
        case .hat: return L10n.garmentHat
        case .scarf: return L10n.garmentScarf
        case .bag: return L10n.garmentBag
        case .socks: return L10n.garmentSocks
        }
    }

    var icon: String {
        switch self {
        case .top: return "tshirt.fill"
        case .bottom: return "figure.stand"
        case .dress: return "figure.stand.dress"
        case .jacket: return "tag.fill"
        case .glasses: return "eyeglasses"
        case .sunglasses: return "sun.max.fill"
        case .hat: return "graduationcap.fill"
        case .scarf: return "wind"
        case .shoes: return "shoe.fill"
        case .bag: return "bag.fill"
        case .socks: return "figure.walk"
        }
    }

    // Kombin validation için
    var conflictsWith: [GarmentType] {
        switch self {
        case .dress:
            return [.top, .bottom] // Elbise ile üst/alt seçilemez (ceket seçilebilir)
        case .top, .bottom:
            return [.dress] // Üst/alt ile elbise seçilemez
        case .jacket:
            return [] // Ceket her şeyle kombine olabilir (elbise+ceket, üst+ceket)
        case .glasses:
            return [.sunglasses] // Gözlük ile güneş gözlüğü birlikte seçilemez
        case .sunglasses:
            return [.glasses] // Güneş gözlüğü ile gözlük birlikte seçilemez
        default:
            return [] // Diğer aksesuarlar conflict yapmaz
        }
    }
}

// MARK: - Garment Model
struct Garment: Identifiable, Codable {
    let id: String
    let imagePath: String         // Encrypted path: users/{userId}/garments/{garmentId}.enc
    let type: GarmentType
    var brand: String?
    var price: Double?
    var currency: String
    var productLink: String?   // 🛒 Ürün satın alma linki
    var isInCart: Bool         // 🛒 Sepette mi?
    let createdAt: Date

    // MARK: - Initialization
    init(
        id: String = UUID().uuidString,
        imagePath: String,
        type: GarmentType,
        brand: String? = nil,
        price: Double? = nil,
        currency: String = "TRY",
        productLink: String? = nil,
        isInCart: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.imagePath = imagePath
        self.type = type
        self.brand = brand
        self.price = price
        self.currency = currency
        self.productLink = productLink
        self.isInCart = isInCart
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties
    var priceFormatted: String? {
        guard let price = price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price))
    }

    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case id
        case imagePath
        case type
        case brand
        case price
        case currency
        case productLink
        case isInCart
        case createdAt
    }

    // MARK: - Custom Decodable (handle missing fields in existing Firestore data)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        type = try container.decode(GarmentType.self, forKey: .type)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "TRY"
        productLink = try container.decodeIfPresent(String.self, forKey: .productLink)
        isInCart = try container.decodeIfPresent(Bool.self, forKey: .isInCart) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
