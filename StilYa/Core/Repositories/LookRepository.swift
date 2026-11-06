//
//  LookRepository.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation

// MARK: - Protocol
protocol LookRepository {
    func saveLook(_ look: Look, userId: String) async throws
    func getLooks(userId: String, limit: Int?) async throws -> [Look]
    func getFavoriteLooks(userId: String) async throws -> [Look]
    func getLook(id: String, userId: String) async throws -> Look?
    func toggleFavorite(lookId: String, userId: String) async throws
    func deleteLook(id: String, userId: String) async throws
}

extension LookRepository {
    func getLooks(userId: String) async throws -> [Look] {
        try await getLooks(userId: userId, limit: nil)
    }
}

// MARK: - Implementation
class LookRepositoryImpl: LookRepository {
    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    func saveLook(_ look: Look, userId: String) async throws {
        try await firestoreService.createInSubcollection(
            look,
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.looks,
            documentId: look.id
        )
    }

    func getLooks(userId: String, limit: Int? = nil) async throws -> [Look] {
        return try await firestoreService.querySubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.looks,
            as: Look.self,
            orderBy: "createdAt",
            descending: true,
            limit: limit
        )
    }

    func getFavoriteLooks(userId: String) async throws -> [Look] {
        let allLooks = try await getLooks(userId: userId)
        return allLooks.filter { $0.isFavorite }
    }

    func getLook(id: String, userId: String) async throws -> Look? {
        let looks = try await getLooks(userId: userId)
        return looks.first { $0.id == id }
    }

    func toggleFavorite(lookId: String, userId: String) async throws {
        guard let look = try await getLook(id: lookId, userId: userId) else {
            throw RepositoryError.lookNotFound
        }

        // Partial update — sadece isFavorite değiştir, tüm dokümanı yeniden yazma
        try await firestoreService.updateInSubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.looks,
            documentId: lookId,
            fields: ["isFavorite": !look.isFavorite]
        )
    }

    func deleteLook(id: String, userId: String) async throws {
        try await firestoreService.deleteFromSubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.looks,
            documentId: id
        )
    }
}
