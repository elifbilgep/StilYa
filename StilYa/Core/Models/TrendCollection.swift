//
//  TrendCollection.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//

import Foundation

struct TrendCollection: Identifiable, Codable, Hashable {
    let id: String
    let titleTR: String
    let titleEN: String
    let category: String
    let gender: String
    let tags: [String]
    let imageUrls: [String]
    let sortOrder: Int
    let createdAt: Date?

    var localizedTitle: String {
        LocalizationManager.shared.currentLanguage == .turkish ? titleTR : titleEN
    }

    enum CodingKeys: String, CodingKey {
        case id, titleTR, titleEN, category, gender, tags, imageUrls, sortOrder, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titleTR = try container.decodeIfPresent(String.self, forKey: .titleTR) ?? ""
        titleEN = try container.decodeIfPresent(String.self, forKey: .titleEN) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "casual"
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? "unisex"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct TrendsResponse: Codable {
    let collections: [TrendCollection]
    let totalCount: Int?
    let page: Int?
    let limit: Int?
    let hasMore: Bool?
}
