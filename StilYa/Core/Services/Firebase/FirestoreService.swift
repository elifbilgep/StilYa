//
//  FirestoreService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import FirebaseFirestore

/// Generic Firestore CRUD operations
class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - Create
    func create<T: Encodable>(
        _ data: T,
        collection: String,
        documentId: String
    ) async throws {
        let encoder = Firestore.Encoder()
        let encoded = try encoder.encode(data)
        try await db.collection(collection).document(documentId).setData(encoded, merge: true)
    }

    // MARK: - Read
    func read<T: Decodable>(
        collection: String,
        documentId: String,
        as type: T.Type
    ) async throws -> T? {
        let snapshot = try await db.collection(collection).document(documentId).getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }

        let decoder = Firestore.Decoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Update
    func update(
        collection: String,
        documentId: String,
        fields: [String: Any]
    ) async throws {
        try await db.collection(collection).document(documentId).updateData(fields)
    }

    // MARK: - Transaction (Atomic operations)
    /// Firestore transaction ile atomik read-write işlemi yapar
    /// Kredi düşme gibi race condition'a açık operasyonlar için kullanılmalı
    func runTransaction(_ updateBlock: @escaping (Transaction, DocumentReference) throws -> Void,
                        collection: String,
                        documentId: String) async throws {
        let docRef = db.collection(collection).document(documentId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                try updateBlock(transaction, docRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    /// Generic transaction: document oku + güncelle (tek atomik işlem)
    func runCreditTransaction<T: Decodable>(
        collection: String,
        documentId: String,
        as type: T.Type,
        updateBlock: @escaping (T) throws -> [String: Any]
    ) async throws {
        let docRef = db.collection(collection).document(documentId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(docRef)
                guard snapshot.exists, let data = snapshot.data() else {
                    throw RepositoryError.userNotFound
                }
                let decoder = Firestore.Decoder()
                let document = try decoder.decode(T.self, from: data)
                let fields = try updateBlock(document)
                transaction.updateData(fields, forDocument: docRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    // MARK: - Delete
    func delete(
        collection: String,
        documentId: String
    ) async throws {
        try await db.collection(collection).document(documentId).delete()
    }

    // MARK: - Query Collection
    func queryCollection<T: Decodable>(
        collection: String,
        as type: T.Type,
        filters: [QueryFilter] = [],
        orderBy: String? = nil,
        descending: Bool = true,
        limit: Int? = nil
    ) async throws -> [T] {
        var query: Query = db.collection(collection)

        // Apply filters
        for filter in filters {
            switch filter.op {
            case .isEqualTo:
                query = query.whereField(filter.field, isEqualTo: filter.value)
            case .isNotEqualTo:
                query = query.whereField(filter.field, isNotEqualTo: filter.value)
            }
        }

        // Apply ordering
        if let orderBy = orderBy {
            query = query.order(by: orderBy, descending: descending)
        }

        // Apply limit
        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let decoder = Firestore.Decoder()

        return try snapshot.documents.compactMap { doc in
            try decoder.decode(T.self, from: doc.data())
        }
    }

    // MARK: - Subcollection Operations
    func createInSubcollection<T: Encodable>(
        _ data: T,
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String,
        documentId: String
    ) async throws {
        let encoder = Firestore.Encoder()
        let encoded = try encoder.encode(data)

        try await db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)
            .document(documentId)
            .setData(encoded)
    }

    func querySubcollection<T: Decodable>(
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String,
        as type: T.Type,
        orderBy: String? = nil,
        descending: Bool = true,
        limit: Int? = nil
    ) async throws -> [T] {
        var query: Query = db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)

        if let orderBy = orderBy {
            query = query.order(by: orderBy, descending: descending)
        }

        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let decoder = Firestore.Decoder()

        return try snapshot.documents.compactMap { doc in
            try decoder.decode(T.self, from: doc.data())
        }
    }

    func querySubcollectionPaginated<T: Decodable>(
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String,
        as type: T.Type,
        orderBy: String,
        descending: Bool = true,
        limit: Int,
        startAfter: DocumentSnapshot? = nil
    ) async throws -> (items: [T], lastDocument: DocumentSnapshot?) {
        var query: Query = db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)
            .order(by: orderBy, descending: descending)

        if let startAfter = startAfter {
            query = query.start(afterDocument: startAfter)
        }

        query = query.limit(to: limit)

        let snapshot = try await query.getDocuments()
        let decoder = Firestore.Decoder()

        let items = try snapshot.documents.compactMap { doc in
            try decoder.decode(T.self, from: doc.data())
        }

        return (items: items, lastDocument: snapshot.documents.last)
    }

    func updateInSubcollection<T: Encodable>(
        _ data: T,
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String,
        documentId: String
    ) async throws {
        let encoder = Firestore.Encoder()
        let encoded = try encoder.encode(data)

        try await db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)
            .document(documentId)
            .setData(encoded, merge: true)
    }

    /// Partial update in subcollection — only modifies specified fields
    func updateInSubcollection(
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String,
        documentId: String,
        fields: [String: Any]
    ) async throws {
        try await db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)
            .document(documentId)
            .updateData(fields)
    }

    func deleteFromSubcollection(
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String,
        documentId: String
    ) async throws {
        try await db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)
            .document(documentId)
            .delete()
    }
    // MARK: - Delete All Documents in Subcollection
    /// Bir subcollection'daki tüm dökümanları siler (batch delete)
    func deleteAllInSubcollection(
        parentCollection: String,
        parentDocumentId: String,
        subcollection: String
    ) async throws {
        let snapshot = try await db
            .collection(parentCollection)
            .document(parentDocumentId)
            .collection(subcollection)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        // Batch delete (max 500 per batch - Firestore limit)
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
        #if DEBUG
        print("🗑️ [Firestore] Deleted \(snapshot.documents.count) documents from \(subcollection)")
        #endif
    }

    // MARK: - Collection Group Query (cross-user)
    func queryCollectionGroup<T: Decodable>(
        collectionId: String,
        as type: T.Type,
        filters: [QueryFilter] = [],
        limit: Int? = nil
    ) async throws -> [T] {
        var query: Query = db.collectionGroup(collectionId)

        for filter in filters {
            switch filter.op {
            case .isEqualTo:
                query = query.whereField(filter.field, isEqualTo: filter.value)
            case .isNotEqualTo:
                query = query.whereField(filter.field, isNotEqualTo: filter.value)
            }
        }

        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let decoder = Firestore.Decoder()

        return try snapshot.documents.compactMap { doc in
            try decoder.decode(T.self, from: doc.data())
        }
    }
}

// MARK: - Query Filter
enum QueryOperator {
    case isEqualTo
    case isNotEqualTo
}

struct QueryFilter {
    let field: String
    let value: Any
    let op: QueryOperator

    init(field: String, value: Any, op: QueryOperator = .isEqualTo) {
        self.field = field
        self.value = value
        self.op = op
    }
}
