//
//  AddToCartSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 26.12.2025.
//

import SwiftUI

struct AddToCartSheet: View {
    @Environment(\.dismiss) private var dismiss

    let garmentImage: UIImage
    let onSave: (String, String?, Double?) -> Void

    @State private var productLink = ""
    @State private var brand = ""
    @State private var price = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var linkPreviewHelper = LinkPreviewHelper()
    @State private var fetchTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case productLink, brand, price
    }

    var isFormValid: Bool {
        true // Tüm alanlar opsiyonel
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                    }

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Hero Garment Image
                        Image(uiImage: garmentImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLG))
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            .padding(.horizontal, Spacing.screenHorizontal)
                            .onTapGesture {
                                focusedField = nil
                            }

                        VStack(spacing: Spacing.md) {
                            // Product Link (Required)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(L10n.tryonCartProductLink)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .onTapGesture {
                                        focusedField = nil
                                    }

                                HStack {
                                    TextFieldCard(
                                        placeholder: L10n.tryonCartProductLinkPlaceholder,
                                        text: $productLink,
                                        icon: "link",
                                        keyboardType: .URL
                                    )
                                    .focused($focusedField, equals: .productLink)

                                    if linkPreviewHelper.isLoading {
                                        ProgressView()
                                            .padding(.leading, Spacing.xs)
                                    }
                                }
                            }

                            // Brand (Optional)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(L10n.tryonCartBrandOptional)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .onTapGesture {
                                        focusedField = nil
                                    }

                                TextFieldCard(
                                    placeholder: L10n.tryonCartBrandPlaceholder,
                                    text: $brand,
                                    icon: "tag.fill"
                                )
                                .focused($focusedField, equals: .brand)
                            }

                            // Price (Optional)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(L10n.tryonCartPriceOptional)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .onTapGesture {
                                        focusedField = nil
                                    }

                                TextFieldCard(
                                    placeholder: L10n.tryonCartPricePlaceholder,
                                    text: $price,
                                    icon: "turkishlirasign",
                                    keyboardType: .decimalPad
                                )
                                .focused($focusedField, equals: .price)
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // Save Button
                        PrimaryButton(
                            title: L10n.tryonCartAddToCartButton,
                            action: saveToCart,
                            isDisabled: !isFormValid
                        )
                        .padding(.horizontal, Spacing.screenHorizontal)

                        Spacer().frame(height: 32)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }
                }
            }
            .navigationTitle(L10n.tryonCartProductInfo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.commonCancel) {
                        dismiss()
                    }
                    .foregroundColor(.textPrimary)
                }
            }
        }
        .alert(L10n.commonError, isPresented: $showError) {
            Button(L10n.commonOk, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: productLink) { oldValue, newValue in
            // Debounce: wait 1 second after user stops typing
            fetchTask?.cancel()
            fetchTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if !Task.isCancelled && isValidURL(newValue) {
                    await fetchMetadata(from: newValue)
                }
            }
        }
    }

    // MARK: - Metadata Fetching

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string), url.scheme != nil else {
            return false
        }
        return true
    }

    @MainActor
    private func fetchMetadata(from urlString: String) async {
        #if DEBUG
        print("🔍 [AddToCart] Fetching metadata for: \(urlString)")
        #endif

        // Use LinkPresentation framework
        if let metadata = await linkPreviewHelper.fetchMetadata(from: urlString) {
            // Auto-fill brand if found and field is empty
            if let fetchedBrand = metadata.brand, brand.isEmpty {
                brand = fetchedBrand
                #if DEBUG
                print("✅ [AddToCart] Auto-filled brand: \(fetchedBrand)")
                #endif
            }

            // Auto-fill price if found and field is empty
            if let fetchedPrice = metadata.price, price.isEmpty {
                price = String(format: "%.2f", fetchedPrice)
                #if DEBUG
                print("✅ [AddToCart] Auto-filled price: \(fetchedPrice)")
                #endif
            }

            if !metadata.isValid {
                #if DEBUG
                print("⚠️ [AddToCart] No metadata found, user will enter manually")
                #endif
            }
        } else {
            #if DEBUG
            print("❌ [AddToCart] Failed to fetch metadata, user will enter manually")
            #endif
        }
    }

    // MARK: - Save

    private func saveToCart() {
        // Validate URL only if user entered one
        var linkValue: String? = nil
        if !productLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let url = URL(string: productLink), url.scheme != nil else {
                errorMessage = L10n.tryonCartInvalidLink
                showError = true
                return
            }
            linkValue = productLink
        }

        // Parse price
        let priceValue = Double(price.replacingOccurrences(of: ",", with: "."))
        let brandValue = brand.isEmpty ? nil : brand

        // Call save callback
        onSave(linkValue ?? "", brandValue, priceValue)

        dismiss()
    }
}

#Preview {
    AddToCartSheet(
        garmentImage: UIImage(systemName: "tshirt.fill")!,
        onSave: { _, _, _ in }
    )
}
