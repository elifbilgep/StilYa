//
//  ImagePreprocessor.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 10.02.2026.
//  Merkezi görüntü ön işleme pipeline'ı - Tüm AI servisleri için tutarlı kalite
//

import UIKit
import Vision

// MARK: - Image Role (hangi amaçla kullanılacağını belirtir)

enum ImageRole {
    case model          // Kullanıcının fotoğrafı (max 1024px, JPEG 0.92)
    case garment        // Kıyafet resmi (max 768px, kontrast+satürasyon artırılır, JPEG 0.95)
    case fluxPerson     // AI kişi resmi (max 1024px - identity korunsun)
    case fluxGarment    // AI garment resmi (max 768px - renk doğruluğu için)
    case shoeGarment    // Ayakkabı resmi (max 768px - serbest oran, crop yok, JPEG 0.95)
}

// MARK: - ImagePreprocessor

final class ImagePreprocessor {
    static let shared = ImagePreprocessor()

    private init() {}

    // MARK: - Public API

    /// Resmi role'üne göre ön işlemden geçirir (boyutlandır + iyileştir)
    func preprocess(_ image: UIImage, for role: ImageRole) -> UIImage {
        switch role {
        case .model:
            return resize(image, maxDimension: 1024)

        case .garment:
            // 9:16 gibi çok uzun referans resimleri AI'ın vücudu uzatmasına neden olur
            // Önce max 3:4 oranına center-crop yap, sonra resize
            let cropped = cropToMaxAspectRatio(image, maxRatio: 3.0 / 4.0)
            return resize(cropped, maxDimension: 768)

        case .fluxPerson:
            // AI kişi resmi: Büyük tut → identity daha iyi korunur
            return resize(image, maxDimension: 1024)

        case .fluxGarment:
            // AI garment resmi: 768px — renk doğruluğu için yeterli çözünürlük
            let cropped = cropToMaxAspectRatio(image, maxRatio: 3.0 / 4.0)
            return resize(cropped, maxDimension: 768)

        case .shoeGarment:
            // Ayakkabı: serbest oran — kullanıcı crop'ta oranı kendisi seçtiği için tekrar kırpma yok
            return resize(image, maxDimension: 768)
        }
    }

    /// Resmi base64 data URI'ye dönüştürür (role'e uygun sıkıştırma)
    /// autoreleasepool ile intermediate Data nesnelerinin hemen serbest bırakılmasını sağlar
    func toBase64DataURI(_ image: UIImage, role: ImageRole, usePNG: Bool = false) -> String? {
        return autoreleasepool {
            if usePNG {
                guard let data = image.pngData() else { return nil }
                let base64 = data.base64EncodedString()
                return "data:image/png;base64,\(base64)"
            }

            let quality = compressionQuality(for: role)
            guard let data = image.jpegData(compressionQuality: quality) else { return nil }
            let base64 = data.base64EncodedString()
            return "data:image/jpeg;base64,\(base64)"
        }
    }

    /// Resmi base64 string'e dönüştürür (data URI prefix'siz)
    func toBase64(_ image: UIImage, role: ImageRole) -> String? {
        return autoreleasepool {
            let quality = compressionQuality(for: role)
            guard let data = image.jpegData(compressionQuality: quality) else { return nil }
            return data.base64EncodedString()
        }
    }

    /// JPEG data döner (role'e uygun sıkıştırma)
    func toJPEGData(_ image: UIImage, role: ImageRole) -> Data? {
        let quality = compressionQuality(for: role)
        return image.jpegData(compressionQuality: quality)
    }

    /// Tam pipeline: preprocess + base64 data URI
    /// autoreleasepool ile intermediate UIImage (processed) hemen serbest bırakılır
    func prepareForAPI(_ image: UIImage, role: ImageRole, usePNG: Bool = false) -> String? {
        return autoreleasepool {
            let processed = preprocess(image, for: role)
            return toBase64DataURI(processed, role: role, usePNG: usePNG)
        }
    }

    /// Tam pipeline: preprocess + JPEG data
    func prepareData(_ image: UIImage, role: ImageRole) -> Data? {
        return autoreleasepool {
            let processed = preprocess(image, for: role)
            return toJPEGData(processed, role: role)
        }
    }

    // MARK: - Private Methods

    /// Role'e göre sıkıştırma kalitesi
    private func compressionQuality(for role: ImageRole) -> CGFloat {
        switch role {
        case .model:         return 0.92
        case .garment:       return 0.95
        case .fluxPerson:    return 0.90
        case .fluxGarment:   return 0.95
        case .shoeGarment:   return 0.95
        }
    }

    /// En boy oranını koruyarak boyutlandır (UIGraphicsImageRenderer kullanır)
    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Vision framework ile arka planı kaldırır (kişi segmentasyonu)
    /// iOS 15+ VNGeneratePersonSegmentationRequest kullanır
    /// Simulator'da Neural Engine yoksa .balanced'a düşer
    /// Başarısızlıkta orijinal resmi döner
    func removeBackground(_ image: UIImage) async -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        // .accurate → Neural Engine gerektirir (simulator'da yok)
        // Başarısız olursa .balanced ile tekrar dene
        let qualityLevels: [VNGeneratePersonSegmentationRequest.QualityLevel] = [.accurate, .balanced]

        for quality in qualityLevels {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = quality
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])

                guard let observation = request.results?.first else {
                    #if DEBUG
                    print("⚠️ [Preprocessor] No person segmentation result (quality: \(quality))")
                    #endif
                    continue
                }

                // Mask'ı CIImage'e çevir
                let maskImage = CIImage(cvPixelBuffer: observation.pixelBuffer)
                let originalImage = CIImage(cgImage: cgImage)

                // Mask'ı orijinal resim boyutuna scale et
                let scaleX = originalImage.extent.width / maskImage.extent.width
                let scaleY = originalImage.extent.height / maskImage.extent.height
                let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                // Mask'ı hafif genişlet — şeffaf kumaş, tül, saç kenarlarını korur
                let dilatedMask: CIImage
                if let dilateFilter = CIFilter(name: "CIMorphologyMaximum") {
                    dilateFilter.setValue(scaledMask, forKey: kCIInputImageKey)
                    dilateFilter.setValue(6.0, forKey: kCIInputRadiusKey) // 6px genişletme — saç/kumaş kenarlarını korur, beyaz halo oluşturmaz
                    dilatedMask = dilateFilter.outputImage ?? scaledMask
                } else {
                    dilatedMask = scaledMask
                }

                // Şeffaf arka plan oluştur
                let background = CIImage.empty()

                guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { continue }
                blendFilter.setValue(originalImage, forKey: kCIInputImageKey)
                blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
                blendFilter.setValue(dilatedMask, forKey: kCIInputMaskImageKey)

                guard let outputImage = blendFilter.outputImage else { continue }

                let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
                guard let outputCG = context.createCGImage(outputImage, from: originalImage.extent) else {
                    continue
                }

                let finalImage = UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
                #if DEBUG
                print("✅ [Preprocessor] Background removed successfully (quality: \(quality))")
                #endif
                return finalImage

            } catch {
                #if DEBUG
                print("⚠️ [Preprocessor] Background removal failed with \(quality): \(error.localizedDescription), trying next...")
                #endif
                continue
            }
        }

        #if DEBUG
        print("❌ [Preprocessor] Background removal failed with all quality levels")
        #endif
        return image
    }

    /// Şeffaf arka planlı görseli kişinin etrafından tight crop yapar.
    func trimTransparentPixels(_ image: UIImage, padding: CGFloat = 0.03) -> UIImage {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        var minX = width, minY = height, maxX = 0, maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha: UInt8 = bytesPerPixel == 4 ? bytes[offset + 3] : 255
                if alpha > 10 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX > minX, maxY > minY else { return image }

        let padX = Int(CGFloat(maxX - minX) * padding)
        let padY = Int(CGFloat(maxY - minY) * padding)
        let cropRect = CGRect(
            x: max(0, minX - padX),
            y: max(0, minY - padY),
            width: min(width - max(0, minX - padX), (maxX - minX) + padX * 2),
            height: min(height - max(0, minY - padY), (maxY - minY) + padY * 2)
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Vision framework ile kıyafet arka planını kaldırır (nesne segmentasyonu)
    /// iOS 17+ VNGenerateForegroundInstanceMaskRequest kullanır
    /// Beyaz arka plan üzerine composite eder (JPEG uyumlu)
    /// Başarısızlıkta orijinal resmi döner
    func removeGarmentBackground(_ image: UIImage) async -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                #if DEBUG
                print("⚠️ [Preprocessor] No foreground instance mask result")
                #endif
                return image
            }

            // Tüm instance'ları birleştiren mask al
            let allIndices = observation.allInstances
            let maskBuffer = try observation.generateScaledMaskForImage(forInstances: allIndices, from: handler)

            let maskImage = CIImage(cvPixelBuffer: maskBuffer)
            let originalImage = CIImage(cgImage: cgImage)

            // Mask'ı orijinal resim boyutuna scale et
            let scaleX = originalImage.extent.width / maskImage.extent.width
            let scaleY = originalImage.extent.height / maskImage.extent.height
            let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // Şeffaf arka plan oluştur (PNG uyumlu)
            let background = CIImage.empty()

            // Mask ile ön planı kes, arka planı şeffaf yap
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return image }
            blendFilter.setValue(originalImage, forKey: kCIInputImageKey)
            blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)

            guard let outputImage = blendFilter.outputImage else { return image }

            let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
            guard let outputCG = context.createCGImage(outputImage, from: originalImage.extent) else {
                return image
            }

            let finalImage = UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
            #if DEBUG
            print("✅ [Preprocessor] Garment background removed successfully")
            #endif
            return finalImage

        } catch {
            #if DEBUG
            print("❌ [Preprocessor] Garment background removal failed: \(error)")
            #endif
            return image
        }
    }

    /// Çok uzun/geniş resimleri hedef orana center-crop eder
    /// Örn: 9:16 resim → 3:4'e kırpılır (üst ve alttan kesilir)
    /// Resim zaten hedef orandan daha geniş/kare ise dokunmaz
    private func cropToMaxAspectRatio(_ image: UIImage, maxRatio: CGFloat) -> UIImage {
        let size = image.size
        let currentRatio = size.width / size.height

        // Resim hedef orandan geniş veya eşitse kırpmaya gerek yok
        // (maxRatio = 0.75 yani 3:4, currentRatio < 0.75 ise çok dar/uzun demek)
        guard currentRatio < maxRatio else { return image }

        // Yeni yüksekliği hesapla (genişlik sabit, yükseklik kısaltılır)
        let newHeight = size.width / maxRatio
        let yOffset = (size.height - newHeight) / 2  // Ortadan kırp

        guard let cgImage = image.cgImage else { return image }

        let cropRect = CGRect(
            x: 0,
            y: yOffset * image.scale,
            width: size.width * image.scale,
            height: newHeight * image.scale
        )

        guard let croppedCG = cgImage.cropping(to: cropRect) else { return image }
        let result = UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
        #if DEBUG
        print("✂️ [Preprocessor] Garment cropped from \(Int(size.width))x\(Int(size.height)) (ratio: \(String(format: "%.2f", currentRatio))) → \(Int(result.size.width))x\(Int(result.size.height)) (ratio: \(String(format: "%.2f", maxRatio)))")
        #endif
        return result
    }

}

// MARK: - Network Retry Helper

/// AI API çağrıları için retry mekanizması (exponential backoff)
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504],
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            // İptal kontrolü
            try Task.checkCancellation()
            return try await operation()
        } catch {
            lastError = error

            // İptal edildiyse retry yapma
            if error is CancellationError { throw error }

            // HTTP hata kodunu kontrol et
            let shouldRetry = isRetryableError(error, retryableStatusCodes: retryableStatusCodes)

            if shouldRetry && attempt < maxAttempts {
                let delay = initialDelay * pow(2.0, Double(attempt - 1)) // 1s, 2s, 4s
                #if DEBUG
                print("🔄 Retry attempt \(attempt)/\(maxAttempts) after \(delay)s...")
                #endif
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else if !shouldRetry {
                // Retry yapılamayacak hata, hemen fırlat
                throw error
            }
        }
    }

    throw lastError ?? NSError(domain: "RetryError", code: -1)
}

/// Hatanın retry yapılabilir olup olmadığını kontrol eder
private func isRetryableError(_ error: Error, retryableStatusCodes: Set<Int>) -> Bool {
    // URL hatası (timeout, bağlantı kesildi vs.)
    if let urlError = error as? URLError {
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    // Servis-specific hataları kontrol et
    let errorDescription = error.localizedDescription.lowercased()

    // HTTP status code içeren hatalar
    for code in retryableStatusCodes {
        if errorDescription.contains("http \(code)") || errorDescription.contains("(\(code))") {
            return true
        }
    }

    // Rate limit / server error mesajları
    if errorDescription.contains("rate limit") ||
       errorDescription.contains("too many requests") ||
       errorDescription.contains("server error") ||
       errorDescription.contains("service unavailable") {
        return true
    }

    return false
}
