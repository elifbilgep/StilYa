//
//  ClosetColorSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 25.03.2026.
//  Profile: Change closet color
//

import SwiftUI

struct ClosetColorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var selectedColor: String
    @State private var isSaving = false
    let currentColor: String
    var onSaved: ((String) -> Void)?

    init(currentColor: String, onSaved: ((String) -> Void)? = nil) {
        self.currentColor = currentColor
        self._selectedColor = State(initialValue: currentColor)
        self.onSaved = onSaved
    }

    private var selectedOption: ClosetColorOption {
        ClosetColorOption(rawValue: selectedColor) ?? .darkWood
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // Closet preview
                    WardrobeIllustration(
                        colorScheme: ClosetColorScheme.scheme(for: selectedOption)
                    )
                    .frame(width: 165, height: 215)
                    .animation(.easeInOut(duration: 0.3), value: selectedColor)

                    Spacer().frame(height: 32)

                    // Color grid (2 rows of 5)
                    colorGrid

                    Spacer()

                    // Save button
                    PrimaryButton(title: L10n.commonSave) {
                        Task {
                            await saveColor()
                        }
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: 40)
                }
            }
            .navigationTitle(L10n.profileClosetColorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.commonClose) {
                        dismiss()
                    }
                    .foregroundColor(.textPrimary)
                }
            }
        }
    }

    // MARK: - Color Grid

    private var colorGrid: some View {
        let allOptions = ClosetColorOption.allCases
        let topRow = Array(allOptions.prefix(5))
        let bottomRow = Array(allOptions.suffix(from: 5))

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ForEach(topRow) { option in
                    colorCircle(option: option)
                }
            }
            HStack(spacing: 20) {
                ForEach(bottomRow) { option in
                    colorCircle(option: option)
                }
            }
        }
    }

    private func colorCircle(option: ClosetColorOption) -> some View {
        let scheme = ClosetColorScheme.scheme(for: option)
        let isSelected = selectedColor == option.rawValue

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedColor = option.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [scheme.frameLight, scheme.frameMid, scheme.frameDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .overlay(
                        Circle()
                            .stroke(Color.accent, lineWidth: isSelected ? 2.5 : 0)
                            .padding(-3)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(option.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accent : .textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 52)
        }
    }

    // MARK: - Save

    private func saveColor() async {
        guard selectedColor != currentColor else {
            dismiss()
            return
        }

        isSaving = true
        do {
            guard let userId = container.authRepository.getCurrentUserId() else { return }
            try await container.userRepository.updateClosetColor(userId: userId, closetColor: selectedColor)
            onSaved?(selectedColor)
            dismiss()
        } catch {
            #if DEBUG
            print("❌ [ClosetColorSheet] Save failed: \(error)")
            #endif
        }
        isSaving = false
    }
}

#Preview {
    ClosetColorSheet(currentColor: "darkWood")
}
