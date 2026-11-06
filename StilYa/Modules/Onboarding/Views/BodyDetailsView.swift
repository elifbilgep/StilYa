//
//  BodyDetailsView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//  Onboarding step: Body photo + Height & Body Type selection
//

import SwiftUI
import PhotosUI

struct BodyDetailsView: View {
    @Binding var bodyPhoto: UIImage?
    @Binding var heightCm: Int?
    @Binding var bodyType: String?
    var gender: String = "unspecified"
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoadingImage = false

    private let sectionTitleFont = STFont.displayCaption

    // Height picker range (cm). `nil` = not specified.
    private let heightOptions: [Int] = Array(140...210)

    // Body-type grid columns
    private let bodyTypeColumns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    private var exampleImageName: String {
        gender == "male" ? "body-example-male" : "body-example-female"
    }

    // Body type options — rawValue MUST match the worker's allowed list.
    private enum BodyTypeOption: String, CaseIterable {
        case slim, average, athletic, curvy, plus

        var label: String {
            switch self {
            case .slim: return L10n.onboardingBodyDetailsBodyTypeSlim
            case .average: return L10n.onboardingBodyDetailsBodyTypeAverage
            case .athletic: return L10n.onboardingBodyDetailsBodyTypeAthletic
            case .curvy: return L10n.onboardingBodyDetailsBodyTypeCurvy
            case .plus: return L10n.onboardingBodyDetailsBodyTypePlus
            }
        }

        var icon: String {
            switch self {
            case .slim: return "figure.stand"
            case .average: return "figure.arms.open"
            case .athletic: return "figure.strengthtraining.functional"
            case .curvy: return "figure.walk"
            case .plus: return "figure.wave"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Title & Explanation
                        VStack(spacing: Spacing.md) {
                            Text(L10n.onboardingBodyDetailsTitle)
                                .font(STFont.displayMedium)
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(L10n.onboardingBodyDetailsSubtitle)
                                .font(STFont.bodyMedium)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.lg)
                        }
                        .padding(.top, 40)

                        Spacer().frame(height: Spacing.md)

                        // Body photo upload
                        if let photo = bodyPhoto {
                            // Preview — portrait vertical card, centered
                            VStack(spacing: Spacing.sm) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 180, height: 240)
                                        .clipped()
                                        .cornerRadius(Spacing.cardRadius)

                                    // Remove button
                                    Button {
                                        bodyPhoto = nil
                                        selectedItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .shadow(radius: 3)
                                    }
                                    .padding(6)
                                }

                                // Change button
                                PhotosPicker(
                                    selection: $selectedItem,
                                    matching: .images
                                ) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 13, weight: .medium))
                                        Text(L10n.onboardingUploadChangePhoto)
                                            .font(STFont.labelSmall)
                                    }
                                    .foregroundColor(.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            // Empty state — example reference image + upload CTA
                            VStack(spacing: Spacing.md) {
                                ZStack(alignment: .topLeading) {
                                    Image(exampleImageName)
                                        .resizable()
                                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                        .frame(width: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                                .stroke(Color.border.opacity(0.5), lineWidth: 1)
                                        )

                                    // "Example" badge
                                    Text(L10n.onboardingBodyDetailsExampleLabel)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.black.opacity(0.65))
                                        .clipShape(Capsule())
                                        .padding(8)
                                }

                                Text(L10n.onboardingBodyDetailsExampleHint)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Spacing.lg)

                                PhotosPicker(
                                    selection: $selectedItem,
                                    matching: .images
                                ) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(L10n.onboardingUploadBodyPhotoAdd)
                                            .font(STFont.labelMedium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.sm)
                                    .background(Color.accent)
                                    .cornerRadius(Spacing.buttonRadius)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Height selector (optional) — a concrete scale reference the photo lacks
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(L10n.onboardingBodyDetailsHeightTitle)
                                .font(STFont.labelMedium)
                                .foregroundColor(.textPrimary)
                            Text(L10n.onboardingBodyDetailsHeightHint)
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)

                            Menu {
                                Button(L10n.onboardingBodyDetailsHeightNotSet) { heightCm = nil }
                                ForEach(heightOptions.reversed(), id: \.self) { cm in
                                    Button("\(cm) cm") { heightCm = cm }
                                }
                            } label: {
                                HStack {
                                    Text(heightCm != nil ? "\(heightCm!) cm" : L10n.onboardingBodyDetailsHeightNotSet)
                                        .font(STFont.labelMedium)
                                        .foregroundColor(heightCm != nil ? .textPrimary : .textSecondary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(.horizontal, Spacing.md)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                        .fill(Color.bgSecondary.opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                        .stroke(Color.border.opacity(0.5), lineWidth: 1)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // Body type selector (optional)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(L10n.onboardingBodyDetailsBodyTypeTitle)
                                .font(STFont.labelMedium)
                                .foregroundColor(.textPrimary)

                            LazyVGrid(columns: bodyTypeColumns, spacing: Spacing.sm) {
                                ForEach(BodyTypeOption.allCases, id: \.self) { option in
                                    BodyDetailChip(
                                        label: option.label,
                                        icon: option.icon,
                                        iconScale: 0.8,
                                        isSelected: bodyType == option.rawValue,
                                        action: {
                                            bodyType = (bodyType == option.rawValue) ? nil : option.rawValue
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // Privacy & Security tips — checklist
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            BodyTipItem(icon: "lock.shield.fill", text: L10n.onboardingBodyTipEncrypted)
                            BodyTipItem(icon: "eye.slash.fill", text: L10n.onboardingBodyTipPrivate)
                            BodyTipItem(icon: "tshirt.fill", text: L10n.onboardingBodyTipAIOnly)
                            BodyTipItem(icon: "trash.fill", text: L10n.onboardingBodyTipDelete)
                        }
                        .padding(Spacing.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                .fill(Color.bgSecondary.opacity(0.6))
                        )
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }
                    .padding(.bottom, Spacing.xl)
                }
                .onChange(of: selectedItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLoadingImage = true
                        }
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            bodyPhoto = image
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLoadingImage = false
                        }
                    }
                }

                // Continue button — requires body photo
                Button(action: onContinue) {
                    HStack(spacing: Spacing.sm) {
                        Text(L10n.commonContinue)
                            .font(STFont.labelLarge)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing.buttonHeight)
                    .background(bodyPhoto != nil ? Color.accent : Color.accent.opacity(0.4))
                    .cornerRadius(Spacing.buttonRadius)
                }
                .disabled(bodyPhoto == nil)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.lg)
            }

            // iCloud download overlay
            if isLoadingImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text(L10n.modelPhotoDownloading)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
            }
        }
    }
}

// MARK: - Body Tip Item

private struct BodyTipItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accent)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Body Detail Chip

private struct BodyDetailChip: View {
    let label: String
    let icon: String
    let iconScale: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 28 * iconScale, weight: .light))
                    .foregroundColor(isSelected ? .white : .textSecondary)
                    .frame(height: 36)

                Text(label)
                    .font(STFont.labelMedium)
                    .foregroundColor(isSelected ? .white : .textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(isSelected ? Color.accent : Color.bgSecondary.opacity(0.6))
            .cornerRadius(Spacing.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(isSelected ? Color.clear : Color.border.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

#Preview {
    BodyDetailsView(
        bodyPhoto: .constant(nil),
        heightCm: .constant(nil),
        bodyType: .constant(nil),
        onContinue: {},
        onBack: {}
    )
}
