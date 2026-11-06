//
//  StorageRepository.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import UIKit

protocol StorageRepository {
    /// Upload profile image (user avatar)
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String // Returns Storage path

    /// Upload model image (user photo for try-on)
    func uploadModelImage(_ image: UIImage, userId: String) async throws -> String // Returns Storage path

    /// Upload model image as PNG (transparent background)
    func uploadModelImagePNG(_ image: UIImage, userId: String) async throws -> String

    /// Upload encrypted image to custom path (for sensitive data like face selfies)
    func uploadEncryptedImage(_ image: UIImage, path: String, userId: String) async throws -> String

    /// Upload garment image
    func uploadGarmentImage(_ image: UIImage, garmentId: String, userId: String) async throws -> String

    /// Upload look result image
    func uploadLookImage(_ image: UIImage, lookId: String, userId: String) async throws -> String

    /// Generic upload to custom path
    func uploadImage(image: UIImage, path: String) async throws

    /// Download image from path
    func downloadImage(path: String) async throws -> Data

    /// Delete image
    func deleteImage(path: String) async throws

    /// Get download URL for path
    func getDownloadURL(path: String) async throws -> URL
}
