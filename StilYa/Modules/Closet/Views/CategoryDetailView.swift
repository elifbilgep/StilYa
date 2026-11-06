//
//  CategoryDetailView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//  Full-screen vertical shelf view for a single garment category ("See All")
//

import SwiftUI

struct CategoryDetailView: View {
    let title: String
    let garments: [Garment]
    let vm: ClosetViewModel
    let cacheVersion: Int
    var colorScheme: ClosetColorScheme = .darkWoodScheme
    let onBack: () -> Void
    let onDelete: (Garment) -> Void

    private let columns = 3

    private var rows: [[Garment]] {
        var result: [[Garment]] = []
        var current: [Garment] = []
        for g in garments {
            current.append(g)
            if current.count == columns {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private var hasSelectionInCategory: Bool {
        garments.contains { vm.selectedGarments[$0.type]?.id == $0.id }
    }

    var body: some View {
        let _ = cacheVersion

        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(title)
                        .font(STFont.displaySection)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 68)
                .padding(.bottom, 12)

                // Vertical shelves
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            HStack(spacing: 12) {
                                ForEach(rows[rowIndex]) { garment in
                                    garmentCard(garment: garment)
                                        .onAppear {
                                            if garment.id == garments.last?.id {
                                                Task { await vm.loadMoreGarments() }
                                            }
                                        }
                                }
                                if rows[rowIndex].count < columns {
                                    ForEach(0..<(columns - rows[rowIndex].count), id: \.self) { _ in
                                        Color.clear.frame(width: 96, height: 124)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 4)

                            WoodenShelf(colorScheme: colorScheme)
                                .padding(.bottom, 16)
                        }

                        if vm.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 20)
                        }

                        if garments.isEmpty && !vm.isLoadingGarments {
                            VStack(spacing: 12) {
                                Image(systemName: "tshirt")
                                    .font(.system(size: 36))
                                    .foregroundColor(.textSecondary.opacity(0.3))
                                Text(L10n.closetShelfEmpty)
                                    .font(STFont.bodyRegular)
                                    .foregroundColor(.textSecondary.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, hasSelectionInCategory ? 80 : 40)
                }
            }

            // Floating "Done" button
            if hasSelectionInCategory {
                VStack {
                    Spacer()
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text(L10n.closetDoneSelection)
                                .font(STFont.buttonSmall)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(Color.accent)
                                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                        )
                    }
                    .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasSelectionInCategory)
    }

    // MARK: - Garment Card

    private func garmentCard(garment: Garment) -> some View {
        let isSelected = vm.selectedGarments[garment.type]?.id == garment.id
        let image = vm.garmentImage(for: garment.id)

        return Button {
            if isSelected {
                vm.deselectGarment(type: garment.type)
            } else if let img = image {
                vm.selectGarment(garment, image: img)
            }
        } label: {
            ZStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 124)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.bgSecondary)
                        .frame(width: 96, height: 124)
                        .overlay(
                            ProgressView().scaleEffect(0.7)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.proGold : Color.clear, lineWidth: 2)
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete(garment)
            } label: {
                Label(L10n.commonDelete, systemImage: "trash")
            }
        }
        .disabled(vm.isTypeDisabled(garment.type))
    }
}
