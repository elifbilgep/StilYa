//
//  ImagePicker.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 23/12/2024.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - UIKit Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var useFrontCamera: Bool = false
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if useFrontCamera {
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if var image = info[.originalImage] as? UIImage {
                // Mirror front camera photos so the result matches the preview
                if picker.cameraDevice == .front {
                    image = mirrorHorizontally(image)
                }
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        private func mirrorHorizontally(_ image: UIImage) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            return renderer.image { ctx in
                ctx.cgContext.translateBy(x: image.size.width, y: 0)
                ctx.cgContext.scaleBy(x: -1, y: 1)
                image.draw(at: .zero)
            }
        }
    }
}

// MARK: - PHPickerViewController (Photo Library)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var isLoading: Binding<Bool>?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        // Use .current to avoid iCloud full-res downloads that hang indefinitely
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        private var didFinish = false
        private var timeoutWork: DispatchWorkItem?
        private var pendingCount = 0

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                parent.dismiss()
                return
            }

            didFinish = false

            DispatchQueue.main.async {
                self.parent.isLoading?.wrappedValue = true
            }

            #if DEBUG
            let types = provider.registeredTypeIdentifiers
            print("🔵 [Picker] Provider types: \(types)")
            #endif

            // Start timeout — if nothing returns in 15s, bail out
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, !self.didFinish else { return }
                self.didFinish = true
                self.timeoutWork = nil
                #if DEBUG
                print("⏰ [Picker] Timeout — no strategy returned in 30s")
                #endif
                self.parent.isLoading?.wrappedValue = false
                self.parent.dismiss()
            }
            timeoutWork = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)

            // Race all available strategies — first one wins
            var launched = 0

            // Strategy 1: JPEG data (fastest, avoids PNG export bug)
            if provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
                launched += 1
                #if DEBUG
                print("🔵 [Picker] Trying JPEG data...")
                #endif
                provider.loadDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier) { [weak self] data, error in
                    #if DEBUG
                    if let error { print("⚠️ [Picker] JPEG failed: \(error.localizedDescription)") }
                    #endif
                    if let data, let image = UIImage(data: data) {
                        self?.finish(with: image)
                    } else {
                        self?.strategyFailed()
                    }
                }
            }

            // Strategy 2: PNG data
            if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                launched += 1
                #if DEBUG
                print("🔵 [Picker] Trying PNG data...")
                #endif
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { [weak self] data, error in
                    #if DEBUG
                    if let error { print("⚠️ [Picker] PNG failed: \(error.localizedDescription)") }
                    #endif
                    if let data, let image = UIImage(data: data) {
                        self?.finish(with: image)
                    } else {
                        self?.strategyFailed()
                    }
                }
            }

            // Strategy 3: loadObject (simple UIImage)
            if provider.canLoadObject(ofClass: UIImage.self) {
                launched += 1
                #if DEBUG
                print("🔵 [Picker] Trying loadObject...")
                #endif
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    #if DEBUG
                    if let error { print("⚠️ [Picker] loadObject failed: \(error.localizedDescription)") }
                    #endif
                    if let image = image as? UIImage {
                        self?.finish(with: image)
                    } else {
                        self?.strategyFailed()
                    }
                }
            }

            // Strategy 4: File representation (works for most types including PNG)
            for type in [UTType.png, UTType.jpeg, UTType.heic] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                launched += 1
                let typeId = type.identifier
                #if DEBUG
                print("🔵 [Picker] Trying file representation for \(typeId)...")
                #endif
                provider.loadFileRepresentation(forTypeIdentifier: typeId) { [weak self] url, error in
                    #if DEBUG
                    if let error { print("⚠️ [Picker] File rep (\(typeId)) failed: \(error.localizedDescription)") }
                    #endif
                    if let url, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        self?.finish(with: image)
                    } else {
                        self?.strategyFailed()
                    }
                }
                break // Only try the first matching type
            }

            pendingCount = launched

            if launched == 0 {
                #if DEBUG
                print("❌ [Picker] No loading strategy available")
                #endif
                finish(with: nil)
            }
        }

        private func strategyFailed() {
            DispatchQueue.main.async {
                self.pendingCount -= 1
                #if DEBUG
                print("⚠️ [Picker] Strategy returned nil, remaining: \(self.pendingCount)")
                #endif
                if self.pendingCount <= 0 {
                    self.finish(with: nil)
                }
            }
        }

        private func finish(with image: UIImage?) {
            DispatchQueue.main.async {
                guard !self.didFinish else { return }
                self.didFinish = true
                self.timeoutWork?.cancel()
                self.timeoutWork = nil
                self.parent.isLoading?.wrappedValue = false
                if let image {
                    self.parent.selectedImage = image
                }
                self.parent.dismiss()
            }
        }
    }
}

// MARK: - Multi Photo Library Picker

struct MultiPhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var maxSelection: Int = 3
    var isLoading: Binding<Bool>?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = maxSelection
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiPhotoLibraryPicker

        init(_ parent: MultiPhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                parent.dismiss()
                return
            }

            DispatchQueue.main.async {
                self.parent.isLoading?.wrappedValue = true
            }

            let group = DispatchGroup()
            var loaded: [(Int, UIImage)] = []

            for (index, result) in results.enumerated() {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            loaded.append((index, image))
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.parent.isLoading?.wrappedValue = false
                self.parent.selectedImages = loaded.sorted(by: { $0.0 < $1.0 }).map(\.1)
                self.parent.dismiss()
            }
        }
    }
}

// MARK: - Combined Image Picker Sheet

struct ImagePickerSheet: View {
    enum Source {
        case camera
        case photoLibrary
    }

    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showCameraPermissionAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // Title
            Text(L10n.imagePickerTitle)
                .font(STFont.titleLarge)
                .foregroundColor(Color.textPrimary)
                .padding(.top, Spacing.lg)

            // Options
            VStack(spacing: Spacing.md) {
                // Camera button
                Button {
                    checkCameraPermission()
                } label: {
                    HStack(spacing: Spacing.lg) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.accent)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.imagePickerTakePhoto)
                                .font(STFont.titleMedium)
                                .foregroundColor(Color.textPrimary)

                            Text(L10n.imagePickerTakePhotoDesc)
                                .font(STFont.bodyMedium)
                                .foregroundColor(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusMD)
                            .fill(Color.bgSecondary)
                    )
                }
                .buttonStyle(.plain)

                // Photo Library button
                Button {
                    showPhotoLibrary = true
                } label: {
                    HStack(spacing: Spacing.lg) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.accent)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.imagePickerGallery)
                                .font(STFont.titleMedium)
                                .foregroundColor(Color.textPrimary)

                            Text(L10n.imagePickerGalleryDesc)
                                .font(STFont.bodyMedium)
                                .foregroundColor(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusMD)
                            .fill(Color.bgSecondary)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.xl)

            Spacer()
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.bgPrimary)
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedImage)
                .ignoresSafeArea()
                .preferredColorScheme(.light)
                .onDisappear {
                    if selectedImage != nil {
                        isPresented = false
                    }
                }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker(selectedImage: $selectedImage)
                .ignoresSafeArea()
                .preferredColorScheme(.light)
                .onDisappear {
                    if selectedImage != nil {
                        isPresented = false
                    }
                }
        }
        .alert(L10n.onboardingUploadCameraPermission, isPresented: $showCameraPermissionAlert) {
            Button(L10n.commonSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.onboardingUploadCameraPermissionDesc)
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }
}

// Import AVFoundation for camera permission
import AVFoundation
