//
//  TryOnResult.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import UIKit

/// Temporary try-on result (not saved to Firestore/Storage yet)
/// Only saved when user taps "Profilime Ekle"
struct TryOnResult {
    let imageData: Data            // JPEG data from API
    let garments: [Garment]        // Which garments were used
    let processingTime: TimeInterval
    let timestamp: Date

    // MARK: - Initialization
    init(
        imageData: Data,
        garments: [Garment],
        processingTime: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.imageData = imageData
        self.garments = garments
        self.processingTime = processingTime
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties
    var isCombo: Bool {
        garments.count > 1
    }

    var image: UIImage? {
        UIImage(data: imageData)
    }

    // MARK: - Convert to Look
    /// Converts this temporary result to a persistent Look entity
    func toLook(resultImagePath: String) -> Look {
        Look(
            resultImagePath: resultImagePath,
            garments: garments,
            isCombo: isCombo,
            processingTime: processingTime,
            createdAt: timestamp
        )
    }
}
