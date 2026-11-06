//
//  ImageCropSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 09.02.2026.
//

import SwiftUI

struct ImageCropSheet: View {
    @Binding var image: UIImage
    let originalImage: UIImage?  // Orijinal resim (reset için)
    let garmentType: GarmentType?  // Kıyafet tipine göre kırpma oranı
    let onDismiss: () -> Void
    let onCancel: (() -> Void)?  // İptal callback'i (seçimi geri almak için)

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var displayImage: UIImage

    // Shoes serbest kırpma
    @State private var dynamicCropWidth: CGFloat = 280
    @State private var dynamicCropHeight: CGFloat = 280
    @State private var lastCropWidth: CGFloat = 280
    @State private var lastCropHeight: CGFloat = 280
    @State private var isDraggingCorner: Bool = false

    // Başlangıç crop boyutları (reset için)
    @State private var initialCropWidth: CGFloat = 280
    @State private var initialCropHeight: CGFloat = 280

    // Ayakkabı crop modu
    @State private var shoeCropMode: ShoeCropMode = .freeform

    enum ShoeCropMode: String, CaseIterable {
        case square = "square"
        case freeform = "freeform"

        var icon: String {
            switch self {
            case .square: return "square"
            case .freeform: return "rectangle"
            }
        }

        var label: String {
            switch self {
            case .square: return "1:1"
            case .freeform: return "3:4"
            }
        }
    }

    private var isShoes: Bool { garmentType == .shoes }

    // Shoes min/max sınırları
    private let shoeMinSize: CGFloat = 150
    private let shoeMaxWidth: CGFloat = 300
    private let shoeMaxHeight: CGFloat = 400

    // Kırpma alanı — kıyafet tipine göre farklı boyut
    private var cropWidth: CGFloat {
        if isShoes { return dynamicCropWidth }
        switch garmentType {
        case .bottom, .dress:
            return 220  // Daha dar
        case .top, .jacket:
            return 280  // Standart genişlik
        default:
            return 280
        }
    }

    private var cropHeight: CGFloat {
        if isShoes { return dynamicCropHeight }
        switch garmentType {
        case .bottom, .dress:
            return 330  // Uzun (2:3 oran)
        case .top, .jacket:
            return 340  // Biraz uzun (3:4 oran)
        default:
            return 280  // Kare (aksesuar vb.)
        }
    }

    // AI output boyutu — kıyafet tipine göre
    private var outputWidth: CGFloat {
        if isShoes {
            // En uzun kenar 768px, orana orantılı
            let ratio = dynamicCropWidth / dynamicCropHeight
            if ratio >= 1.0 {
                return 768
            } else {
                return 768 * ratio
            }
        }
        switch garmentType {
        case .bottom, .dress:
            return 512     // 512x768 (2:3)
        case .top, .jacket:
            return 576     // 576x768 (3:4)
        default:
            return 512     // 512x512 (kare)
        }
    }

    private var outputHeight: CGFloat {
        if isShoes {
            let ratio = dynamicCropWidth / dynamicCropHeight
            if ratio >= 1.0 {
                return 768 / ratio
            } else {
                return 768
            }
        }
        switch garmentType {
        case .bottom, .dress:
            return 768     // 512x768 (2:3)
        case .top, .jacket:
            return 768     // 576x768 (3:4)
        default:
            return 512     // 512x512 (kare)
        }
    }

    private var cropGuideText: String {
        switch garmentType {
        case .top, .jacket:
            return L10n.tryonCropTopGuide
        case .bottom:
            return L10n.tryonCropBottomGuide
        case .dress:
            return L10n.tryonCropDressGuide
        case .shoes:
            return L10n.tryonCropShoesGuide
        default:
            return L10n.tryonCropDefaultGuide
        }
    }

    init(image: Binding<UIImage>, originalImage: UIImage? = nil, garmentType: GarmentType? = nil, onDismiss: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self._image = image
        self.originalImage = originalImage
        self.garmentType = garmentType
        self.onDismiss = onDismiss
        self.onCancel = onCancel

        let img = originalImage ?? image.wrappedValue
        self._displayImage = State(initialValue: img)

        let imageSize = img.size
        let imageAspect = imageSize.width / imageSize.height

        let cropW: CGFloat
        let cropH: CGFloat

        if garmentType == .shoes {
            // Ayakkabı: görselin oranına göre başlangıç crop boyutu hesapla
            let maxW: CGFloat = 300
            let maxH: CGFloat = 400
            let minS: CGFloat = 150

            if imageAspect >= 1.0 {
                // Yatay görsel → geniş crop
                cropW = maxW
                cropH = max(minS, min(maxH, maxW / imageAspect))
            } else {
                // Dikey görsel → uzun crop
                cropH = maxH
                cropW = max(minS, min(maxW, maxH * imageAspect))
            }

            self._dynamicCropWidth = State(initialValue: cropW)
            self._dynamicCropHeight = State(initialValue: cropH)
            self._lastCropWidth = State(initialValue: cropW)
            self._lastCropHeight = State(initialValue: cropH)
            self._initialCropWidth = State(initialValue: cropW)
            self._initialCropHeight = State(initialValue: cropH)
        } else {
            switch garmentType {
            case .bottom, .dress:
                cropW = 220
                cropH = 330
            case .top, .jacket:
                cropW = 280
                cropH = 340
            default:
                cropW = 280
                cropH = 280
            }
        }

        // Başlangıç scale'ini hesapla - crop area'yı tamamen kapsamalı
        let cropAspect = cropW / cropH

        var fitWidth: CGFloat
        var fitHeight: CGFloat

        if imageAspect > cropAspect {
            fitHeight = cropH
            fitWidth = cropH * imageAspect
        } else {
            fitWidth = cropW
            fitHeight = cropW / imageAspect
        }

        let minScale = max(cropW / fitWidth, cropH / fitHeight)
        self._scale = State(initialValue: minScale)
        self._lastScale = State(initialValue: minScale)
    }

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Color.clear
                        .frame(width: 36, height: 36)

                    Spacer()

                    Text(L10n.tryonCropCrop)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer()

                // Crop area — kıyafet tipine göre boyut
                ZStack {
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropWidth, height: cropHeight)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            isDraggingCorner ? nil :
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        let minScale = calculateMinScale()
                                        scale = min(max(newScale, minScale), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        offset = constrainOffset(offset, scale: scale)
                                        lastOffset = offset
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = constrainOffset(newOffset, scale: scale)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropWidth, height: cropHeight)

                    if isShoes {
                        ResizableCropCornerHandles(
                            width: cropWidth,
                            height: cropHeight,
                            onDragChanged: { corner, translation in
                                isDraggingCorner = true
                                handleCornerDrag(corner: corner, translation: translation)
                            },
                            onDragEnded: {
                                isDraggingCorner = false
                                lastCropWidth = dynamicCropWidth
                                lastCropHeight = dynamicCropHeight
                                // Scale'i yeniden hesapla
                                let minScale = calculateMinScale()
                                if scale < minScale {
                                    scale = minScale
                                    lastScale = minScale
                                }
                                offset = constrainOffset(offset, scale: scale)
                                lastOffset = offset
                            }
                        )
                    } else {
                        CropCornerHandles(width: cropWidth, height: cropHeight)
                    }
                }
                .frame(width: cropWidth, height: cropHeight)
                .clipped()
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dynamicCropWidth)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dynamicCropHeight)

                Spacer()

                // Bottom section
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // İptal butonu
                        Button {
                            onCancel?()
                            onDismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .medium))
                                Text(L10n.commonCancel)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 80)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        if originalImage != nil {
                            Button {
                                resetToOriginal()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 13, weight: .medium))
                                    Text(L10n.tryonCropReset)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(minWidth: 80)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }

                        Button {
                            cropImage()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(L10n.tryonCropApply)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 80)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.accent)
                            .clipShape(Capsule())
                        }
                    }

                    if isShoes {
                        // Kare / Dikdörtgen seçimi
                        HStack(spacing: 8) {
                            ForEach(ShoeCropMode.allCases, id: \.self) { mode in
                                Button {
                                    switchShoeCropMode(mode)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(mode.label)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(shoeCropMode == mode ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(shoeCropMode == mode ? Color.white : Color.white.opacity(0.15))
                                    )
                                }
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        Text(cropGuideText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)

                        Text(isShoes ? L10n.tryonCropResizeHint : L10n.tryonCropBetterOnModel)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Corner Drag (Shoes)

    private func handleCornerDrag(corner: CropCorner, translation: CGSize) {
        // Simetrik resize: köşe sürüklendiğinde width ve height orantılı değişir
        let dx: CGFloat
        let dy: CGFloat

        switch corner {
        case .topLeft:
            dx = -translation.width
            dy = -translation.height
        case .topRight:
            dx = translation.width
            dy = -translation.height
        case .bottomLeft:
            dx = -translation.width
            dy = translation.height
        case .bottomRight:
            dx = translation.width
            dy = translation.height
        }

        // Her iki yönde simetrik olarak genişlet/daralt (2x çarpan: her iki taraftan)
        let newWidth = lastCropWidth + dx * 2
        let newHeight = lastCropHeight + dy * 2

        dynamicCropWidth = min(shoeMaxWidth, max(shoeMinSize, newWidth))
        dynamicCropHeight = min(shoeMaxHeight, max(shoeMinSize, newHeight))
    }

    private func switchShoeCropMode(_ mode: ShoeCropMode) {
        guard mode != shoeCropMode else { return }
        shoeCropMode = mode

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switch mode {
            case .square:
                let size = min(shoeMaxWidth, shoeMaxHeight)
                dynamicCropWidth = size
                dynamicCropHeight = size
            case .freeform:
                // 3:4 dikdörtgen
                dynamicCropWidth = 240
                dynamicCropHeight = 320
            }
            lastCropWidth = dynamicCropWidth
            lastCropHeight = dynamicCropHeight

            // Scale'i yeniden hesapla
            let minScale = calculateMinScale()
            if scale < minScale {
                scale = minScale
                lastScale = minScale
            }
            offset = constrainOffset(offset, scale: scale)
            lastOffset = offset
        }
    }

    private func resetToOriginal() {
        if let original = originalImage {
            displayImage = original

            if isShoes {
                dynamicCropWidth = initialCropWidth
                dynamicCropHeight = initialCropHeight
                lastCropWidth = initialCropWidth
                lastCropHeight = initialCropHeight
            }

            let minScale = calculateMinScale()
            scale = minScale
            lastScale = minScale
            offset = .zero
            lastOffset = .zero
        }
    }

    /// Minimum scale hesapla - crop area'yı tamamen kapsamalı
    private func calculateMinScale() -> CGFloat {
        let imageSize = displayImage.size
        let imageAspect = imageSize.width / imageSize.height
        let cropAspect = cropWidth / cropHeight

        // scaledToFill davranışı için minimum scale
        var fitWidth: CGFloat
        var fitHeight: CGFloat

        if imageAspect > cropAspect {
            // Resim crop'tan daha geniş → yüksekliğe göre sığdır
            fitHeight = cropHeight
            fitWidth = cropHeight * imageAspect
        } else {
            // Resim crop'tan daha dar → genişliğe göre sığdır
            fitWidth = cropWidth
            fitHeight = cropWidth / imageAspect
        }

        // Minimum scale: resim crop area'yı tamamen kapsamalı
        return max(cropWidth / fitWidth, cropHeight / fitHeight)
    }

    /// Offset'i sınırlar içinde tut - resim crop area'nın dışına çıkmasın
    private func constrainOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let imageSize = displayImage.size
        let imageAspect = imageSize.width / imageSize.height
        let cropAspect = cropWidth / cropHeight

        // Scaled image dimensions
        var fitWidth: CGFloat
        var fitHeight: CGFloat

        if imageAspect > cropAspect {
            fitHeight = cropHeight
            fitWidth = cropHeight * imageAspect
        } else {
            fitWidth = cropWidth
            fitHeight = cropWidth / imageAspect
        }

        let scaledWidth = fitWidth * scale
        let scaledHeight = fitHeight * scale

        // Maksimum offset hesapla (resim crop area'nın dışına çıkmamalı)
        let maxOffsetX = max(0, (scaledWidth - cropWidth) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropHeight) / 2)

        // Offset'i sınırla
        let constrainedX = max(-maxOffsetX, min(maxOffsetX, offset.width))
        let constrainedY = max(-maxOffsetY, min(maxOffsetY, offset.height))

        return CGSize(width: constrainedX, height: constrainedY)
    }

    private func cropImage() {
        // Kıyafet tipine göre output boyutu
        let outW = outputWidth
        let outH = outputHeight

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: format)

        let croppedImage = renderer.image { ctx in
            // Beyaz arka plan (kıyafet AI için temiz arka plan)
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))

            let imageSize = displayImage.size
            let imageAspect = imageSize.width / imageSize.height
            let cropAspect = cropWidth / cropHeight

            // scaledToFill davranışını simüle et
            var fitWidth: CGFloat
            var fitHeight: CGFloat

            if imageAspect > cropAspect {
                // Resim crop'tan daha geniş → yüksekliğe göre sığdır
                fitHeight = cropHeight
                fitWidth = cropHeight * imageAspect
            } else {
                // Resim crop'tan daha dar → genişliğe göre sığdır
                fitWidth = cropWidth
                fitHeight = cropWidth / imageAspect
            }

            // Scale uygula
            let scaledWidth = fitWidth * scale
            let scaledHeight = fitHeight * scale

            // Output için ölçekle
            let scaleX = outW / cropWidth
            let scaleY = outH / cropHeight
            let drawWidth = scaledWidth * scaleX
            let drawHeight = scaledHeight * scaleY
            let drawX = (outW - drawWidth) / 2 + (offset.width * scaleX)
            let drawY = (outH - drawHeight) / 2 + (offset.height * scaleY)

            displayImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }

        image = croppedImage
        onDismiss()
    }
}

// MARK: - Crop Corner Enum

enum CropCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Resizable Crop Corner Handles (Shoes)

private struct ResizableCropCornerHandles: View {
    let width: CGFloat
    let height: CGFloat
    let onDragChanged: (CropCorner, CGSize) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        ZStack {
            // Top-left
            resizableCorner(.topLeft)
                .position(x: 0, y: 0)

            // Top-right
            resizableCorner(.topRight)
                .position(x: width, y: 0)

            // Bottom-left
            resizableCorner(.bottomLeft)
                .position(x: 0, y: height)

            // Bottom-right
            resizableCorner(.bottomRight)
                .position(x: width, y: height)
        }
        .frame(width: width, height: height)
    }

    private func resizableCorner(_ corner: CropCorner) -> some View {
        let rotation: Double = {
            switch corner {
            case .topLeft: return 0
            case .topRight: return 90
            case .bottomLeft: return 270
            case .bottomRight: return 180
            }
        }()

        return CornerHandle(rotation: rotation)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onDragChanged(corner, value.translation)
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )
    }
}

// MARK: - Crop Corner Handles (Diğer kıyafetler)

private struct CropCornerHandles: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Top-left
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    CornerHandle(rotation: 0)
                    Spacer()
                }
                Spacer()
            }

            // Top-right
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    CornerHandle(rotation: 90)
                }
                Spacer()
            }

            // Bottom-left
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    CornerHandle(rotation: 270)
                    Spacer()
                }
            }

            // Bottom-right
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    CornerHandle(rotation: 180)
                }
            }
        }
        .frame(width: width, height: height)
    }
}

private struct CornerHandle: View {
    let rotation: Double
    private let length: CGFloat = 24
    private let width: CGFloat = 3

    var body: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white)
                .frame(width: length, height: width)
                .offset(x: length / 2 - width / 2, y: 0)

            // Vertical line
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: length)
                .offset(x: 0, y: length / 2 - width / 2)
        }
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    ImageCropSheet(
        image: .constant(UIImage(systemName: "photo")!),
        originalImage: nil,
        garmentType: .top,
        onDismiss: {}
    )
}
