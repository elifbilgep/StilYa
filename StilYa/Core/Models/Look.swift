//
//  Look.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation

enum LookSource: String, Codable {
    case tryOn = "tryOn"
    case closet = "closet"
}

struct Look: Identifiable, Codable {
    let id: String
    let resultImagePath: String    // Storage path: users/{userId}/looks/{lookId}.jpg
    let garments: [Garment]        // Kullanılan kıyafetler (1 veya 2 adet)
    let isCombo: Bool              // Kombin mi (üst+alt) yoksa tek parça mı
    var isFavorite: Bool
    let processingTime: TimeInterval // API işlem süresi (seconds)
    let createdAt: Date
    let source: LookSource

    // MARK: - Initialization
    init(
        id: String = UUID().uuidString,
        resultImagePath: String,
        garments: [Garment],
        isCombo: Bool = false,
        isFavorite: Bool = false,
        processingTime: TimeInterval = 0,
        createdAt: Date = Date(),
        source: LookSource = .tryOn
    ) {
        self.id = id
        self.resultImagePath = resultImagePath
        self.garments = garments
        self.isCombo = isCombo
        self.isFavorite = isFavorite
        self.processingTime = processingTime
        self.createdAt = createdAt
        self.source = source
    }

    // MARK: - Computed Properties
    var totalPrice: Double? {
        let prices = garments.compactMap { $0.price }
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +)
    }

    var brands: [String] {
        garments.compactMap { $0.brand }
    }

    var garmentTypes: [GarmentType] {
        garments.map { $0.type }
    }

    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case id
        case resultImagePath
        case garments
        case isCombo
        case isFavorite
        case processingTime
        case createdAt
        case source
    }

    // MARK: - Backward-compatible Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        resultImagePath = try container.decode(String.self, forKey: .resultImagePath)
        garments = try container.decode([Garment].self, forKey: .garments)
        isCombo = try container.decode(Bool.self, forKey: .isCombo)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        processingTime = try container.decode(TimeInterval.self, forKey: .processingTime)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        source = try container.decodeIfPresent(LookSource.self, forKey: .source) ?? .tryOn
    }
}
