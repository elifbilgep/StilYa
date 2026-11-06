//
//  PendingModelPhotoManager.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//  Saves onboarding selfie/body photos locally for deferred model photo generation.
//

import UIKit

enum PendingModelPhotoManager {
    private static let pendingKey = "pendingModelPhotoGeneration"
    private static let genderKey = "pendingModelPhotoGender"
    private static let selfieCountKey = "pendingModelPhotoSelfieCount"
    private static let heightKey = "pendingModelPhotoHeightCm"
    private static let bodyTypeKey = "pendingModelPhotoBodyType"

    private static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func selfieURL(index: Int) -> URL {
        documentsDir.appendingPathComponent("pending_selfie_\(index).jpg")
    }

    private static var bodyPhotoURL: URL {
        documentsDir.appendingPathComponent("pending_body.jpg")
    }

    // MARK: - Read

    static var hasPending: Bool {
        UserDefaults.standard.bool(forKey: pendingKey)
    }

    static var pendingGender: String {
        UserDefaults.standard.string(forKey: genderKey) ?? "unspecified"
    }

    static var pendingHeightCm: Int? {
        let v = UserDefaults.standard.integer(forKey: heightKey)
        return v > 0 ? v : nil
    }

    static var pendingBodyType: String? {
        UserDefaults.standard.string(forKey: bodyTypeKey)
    }

    static func loadSelfies() -> [UIImage] {
        let count = UserDefaults.standard.integer(forKey: selfieCountKey)
        var images: [UIImage] = []
        for i in 0..<count {
            if let data = try? Data(contentsOf: selfieURL(index: i)),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        return images
    }

    static func loadBodyPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: bodyPhotoURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Write

    static func save(selfies: [UIImage], bodyPhoto: UIImage?, gender: String, heightCm: Int? = nil, bodyType: String? = nil) {
        for (i, selfie) in selfies.enumerated() {
            if let data = selfie.jpegData(compressionQuality: 0.9) {
                try? data.write(to: selfieURL(index: i))
            }
        }

        if let body = bodyPhoto, let bodyData = body.jpegData(compressionQuality: 0.9) {
            try? bodyData.write(to: bodyPhotoURL)
        }

        UserDefaults.standard.set(true, forKey: pendingKey)
        UserDefaults.standard.set(gender, forKey: genderKey)
        UserDefaults.standard.set(selfies.count, forKey: selfieCountKey)
        if let heightCm = heightCm {
            UserDefaults.standard.set(heightCm, forKey: heightKey)
        } else {
            UserDefaults.standard.removeObject(forKey: heightKey)
        }
        if let bodyType = bodyType {
            UserDefaults.standard.set(bodyType, forKey: bodyTypeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: bodyTypeKey)
        }

        #if DEBUG
        print("💾 [PendingModel] Saved \(selfies.count) selfie(s), body: \(bodyPhoto != nil), gender: \(gender), height: \(heightCm.map(String.init) ?? "nil"), bodyType: \(bodyType ?? "nil")")
        #endif
    }

    // MARK: - Clear

    static func clear() {
        let count = UserDefaults.standard.integer(forKey: selfieCountKey)
        for i in 0..<count {
            try? FileManager.default.removeItem(at: selfieURL(index: i))
        }
        try? FileManager.default.removeItem(at: bodyPhotoURL)

        UserDefaults.standard.removeObject(forKey: pendingKey)
        UserDefaults.standard.removeObject(forKey: genderKey)
        UserDefaults.standard.removeObject(forKey: selfieCountKey)
        UserDefaults.standard.removeObject(forKey: heightKey)
        UserDefaults.standard.removeObject(forKey: bodyTypeKey)

        #if DEBUG
        print("🗑️ [PendingModel] Cleared pending photos")
        #endif
    }
}
