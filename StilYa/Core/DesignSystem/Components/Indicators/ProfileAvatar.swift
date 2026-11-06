//
//  ProfileAvatar.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import SwiftUI

/// Reusable profile avatar circle — used in HomeView header and ProfileView card.
struct ProfileAvatar: View {
    let image: UIImage?
    var size: CGFloat = 72
    var isLoading: Bool = false
    var showCameraBadge: Bool = false

    private var iconSize: CGFloat { size * 0.38 }
    private var borderWidth: CGFloat { size > 50 ? 2 : 1.5 }
    private var badgeSize: CGFloat { size * 0.33 }
    private var badgeIconSize: CGFloat { size * 0.14 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.bgPrimary)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(Color.proGold.opacity(0.3), lineWidth: borderWidth)
                )

            if isLoading {
                ProgressView()
                    .tint(.proGold)
                    .frame(width: size, height: size)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.textSecondary.opacity(0.4))
                    .frame(width: size, height: size)
            }

            if showCameraBadge && !isLoading {
                Circle()
                    .fill(Color.proGold)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: badgeIconSize))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
            }
        }
    }
}
