//
//  GarmentRepository.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Protocol
protocol GarmentRepository {
    func saveGarment(_ garment: Garment, userId: String) async throws
    func getGarments(userId: String) async throws -> [Garment]
    func getGarmentsPaginated(userId: String, limit: Int, startAfter: Any?) async throws -> (garments: [Garment], lastDocument: Any?)
    func getGarment(id: String, userId: String) async throws -> Garment?
    func updateGarment(_ garment: Garment, userId: String) async throws
    func deleteGarment(id: String, userId: String) async throws
}

// MARK: - Implementation
class GarmentRepositoryImpl: GarmentRepository {
    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    func saveGarment(_ garment: Garment, userId: String) async throws {
        try await firestoreService.createInSubcollection(
            garment,
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.garments,
            documentId: garment.id
        )
    }

    func getGarments(userId: String) async throws -> [Garment] {
        return try await firestoreService.querySubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.garments,
            as: Garment.self,
            orderBy: "createdAt",
            descending: true
        )
    }

    func getGarmentsPaginated(userId: String, limit: Int, startAfter: Any?) async throws -> (garments: [Garment], lastDocument: Any?) {
        let cursor = startAfter as? DocumentSnapshot
        let result = try await firestoreService.querySubcollectionPaginated(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.garments,
            as: Garment.self,
            orderBy: "createdAt",
            descending: true,
            limit: limit,
            startAfter: cursor
        )
        return (garments: result.items, lastDocument: result.lastDocument)
    }

    func getGarment(id: String, userId: String) async throws -> Garment? {
        let garments = try await getGarments(userId: userId)
        return garments.first { $0.id == id }
    }

    func updateGarment(_ garment: Garment, userId: String) async throws {
        try await firestoreService.updateInSubcollection(
            garment,
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.garments,
            documentId: garment.id
        )
    }

    func deleteGarment(id: String, userId: String) async throws {
        try await firestoreService.deleteFromSubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.garments,
            documentId: id
        )
    }
}
