//
//  CartView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 26.12.2025.
//

import SwiftUI

struct CartView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var viewModel: CartViewModel?
    @State private var isEditMode = false
    @State private var editingGarment: Garment?
    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if let viewModel = viewModel {
                if viewModel.isLoading {
                    LoadingView(message: L10n.cartLoading)
                } else if viewModel.cartItems.isEmpty {
                    emptyCartView
                } else {
                    cartContentView(viewModel: viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(L10n.cartTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.textPrimary)
                }
            }

        }
        .task {
            // Initialize ViewModel
            let vm = CartViewModel(
                authRepository: container.authRepository,
                garmentRepository: container.garmentRepository,
                storageRepository: container.storageRepository,
                userRepository: container.userRepository
            )
            viewModel = vm

            // Load cart items
            await vm.loadCartItems()
        }
        .sheet(item: $editingGarment) { garment in
            EditGarmentSheet(
                garment: garment,
                garmentImage: viewModel?.garmentImage(for: garment.id),
                onSave: { updatedLink, updatedBrand, updatedPrice in
                    Task {
                        await viewModel?.updateGarment(
                            garment,
                            link: updatedLink,
                            brand: updatedBrand,
                            price: updatedPrice
                        )
                        editingGarment = nil
                    }
                }
            )
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Empty State

    private var emptyCartView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary.opacity(0.3))

            Text(L10n.cartEmpty)
                .font(STFont.titleMedium)
                .foregroundColor(.textPrimary)

            Text(L10n.cartEmptyDescription)
                .font(STFont.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Spacing.xl)

            PrimaryButton(title: L10n.cartStartTrying, action: {
                dismiss()
            })
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .padding(.top, 100)
    }

    // MARK: - Cart Content

    private func cartContentView(viewModel: CartViewModel) -> some View {
        VStack(spacing: 0) {
            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    // All Items Filter
                    FilterChip(
                        title: L10n.cartAll,
                        count: viewModel.cartItems.count,
                        isSelected: viewModel.selectedFilter == nil,
                        onTap: {
                            viewModel.selectedFilter = nil
                            viewModel.clearSelection()
                        }
                    )

                    // Category Filters
                    ForEach(GarmentType.allCases, id: \.self) { type in
                        let count = viewModel.cartItems.filter { $0.type == type }.count
                        if count > 0 {
                            FilterChip(
                                title: type.displayName,
                                count: count,
                                isSelected: viewModel.selectedFilter == type,
                                onTap: {
                                    viewModel.selectedFilter = type
                                    viewModel.clearSelection()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.md)
            }
            .background(Color.bgPrimary)

            Divider()

            // Cart Items List
            ScrollView {
                // Info disclaimer banner
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary.opacity(0.6))

                    Text(L10n.cartDisclaimer)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSM)
                        .fill(Color.bgSecondary.opacity(0.7))
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.sm)
                let _ = viewModel.imagesVersion // trigger re-render on cache changes
                if viewModel.filteredCartItems.isEmpty && viewModel.selectedFilter != nil {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundColor(.textSecondary.opacity(0.3))
                        Text(L10n.cartFilterEmpty)
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack(spacing: Spacing.md) {
                    ForEach(viewModel.filteredCartItems) { garment in
                        CartItemCard(
                            garment: garment,
                            image: viewModel.garmentImage(for: garment.id),
                            hasLink: garment.productLink != nil && !garment.productLink!.isEmpty,
                            isFilterActive: viewModel.selectedFilter != nil,
                            isSelected: viewModel.isSelected(garment.id),
                            onBuy: {
                                if let link = garment.productLink {
                                    viewModel.openProductLink(link)
                                }
                            },
                            onPurchased: {
                                Task {
                                    await viewModel.removeFromCart(garment)
                                }
                            },
                            onEdit: {
                                editingGarment = garment
                                showEditSheet = true
                            },
                            onRemove: {
                                Task {
                                    await viewModel.removeFromCart(garment)
                                }
                            },
                            onToggleSelection: {
                                viewModel.toggleSelection(for: garment.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 100) // Space for bottom bar
            }

            Spacer()

            // Bottom Total Bar
            VStack(spacing: Spacing.sm) {
                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(L10n.cartTotal)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)

                        Text("₺\(String(format: "%.2f", viewModel.totalPrice))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    if viewModel.selectedFilter != nil && !viewModel.selectedItemIds.isEmpty {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteSelected()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(L10n.cartDeleteSelected)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.error)
                            )
                        }
                    } else {
                        Text(L10n.cartItemCount(viewModel.itemCount))
                            .font(STFont.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.md)
            }
            .background(Color.bgPrimary)
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .textSecondary)
            }
            .foregroundColor(isSelected ? .white : .textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusFull)
                    .fill(isSelected ? Color.accent : Color.bgSecondary)
            )
        }
    }
}

// MARK: - Cart Item Card

private struct CartItemCard: View {
    let garment: Garment
    let image: UIImage?
    let hasLink: Bool
    let isFilterActive: Bool
    let isSelected: Bool
    let onBuy: () -> Void
    let onPurchased: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Product Image (compact square)
            ZStack(alignment: .topLeading) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSM))
                } else {
                    RoundedRectangle(cornerRadius: Spacing.radiusSM)
                        .fill(Color.bgSecondary)
                        .frame(width: 100, height: 100)
                        .overlay(ProgressView())
                }

                // Checkbox (only when filter active)
                if isFilterActive {
                    Button(action: onToggleSelection) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.accent : Color.white)
                                .frame(width: 22, height: 22)
                                .shadow(color: .black.opacity(0.1), radius: 2)

                            Image(systemName: isSelected ? "checkmark" : "circle")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isSelected ? .white : .textSecondary)
                        }
                    }
                    .padding(6)
                }
            }

            // Info + Actions
            VStack(alignment: .leading, spacing: 6) {
                // Top row: brand + menu
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let brand = garment.brand {
                            Text(brand)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }

                        Text(garment.type.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    if !isFilterActive {
                        Menu {
                            Button {
                                onEdit()
                            } label: {
                                Label(L10n.commonEdit, systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                onRemove()
                            } label: {
                                Label(L10n.commonDelete, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .frame(width: 28, height: 28)
                        }
                    }
                }

                // Price
                if let price = garment.price {
                    Text("₺\(String(format: "%.2f", price))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                }

                // Buy / Purchased button
                if hasLink {
                    Button(action: onBuy) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L10n.cartBuy)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accent)
                        )
                    }
                } else {
                    Button(action: onPurchased) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L10n.cartPurchased)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.success)
                        )
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMD)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMD)
                .stroke(isFilterActive && isSelected ? Color.accent : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            if isFilterActive {
                onToggleSelection()
            }
        }
    }
}

// MARK: - Edit Garment Sheet

struct EditGarmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let garment: Garment
    let garmentImage: UIImage?
    let onSave: (String, String?, Double?) -> Void

    @State private var productLink: String
    @State private var brand: String
    @State private var price: String
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case productLink, brand, price
    }

    init(garment: Garment, garmentImage: UIImage?, onSave: @escaping (String, String?, Double?) -> Void) {
        self.garment = garment
        self.garmentImage = garmentImage
        self.onSave = onSave
        _productLink = State(initialValue: garment.productLink ?? "")
        _brand = State(initialValue: garment.brand ?? "")
        _price = State(initialValue: garment.price.map { String(format: "%.2f", $0) } ?? "")
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

                        // Garment Image
                        Group {
                            if let image = garmentImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLG))
                                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            } else {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.textSecondary.opacity(0.3))
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.bgSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLG))
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .onTapGesture {
                            focusedField = nil
                        }

                        VStack(spacing: Spacing.md) {
                            // Product Link
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(L10n.tryonCartProductLink)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .onTapGesture {
                                        focusedField = nil
                                    }

                                TextFieldCard(
                                    placeholder: L10n.tryonCartProductLinkPlaceholder,
                                    text: $productLink,
                                    icon: "link",
                                    keyboardType: .URL
                                )
                                .focused($focusedField, equals: .productLink)
                            }

                            // Brand
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

                            // Price
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
                            title: L10n.commonSave,
                            action: save,
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
            .navigationTitle(L10n.cartEditProduct)
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
    }

    private func save() {
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

        let priceValue = Double(price.replacingOccurrences(of: ",", with: "."))
        let brandValue = brand.isEmpty ? nil : brand

        onSave(linkValue ?? "", brandValue, priceValue)
        dismiss()
    }
}

#Preview {
    NavigationView {
        CartView()
    }
}
