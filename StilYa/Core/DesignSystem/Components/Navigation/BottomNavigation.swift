//
//  BottomNavigation.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

enum HomeTab {
    case home
    case looks
    case pro
    case profile

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .looks: return "heart.fill"
        case .pro: return "sparkles"
        case .profile: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .looks: return "Look'lar"
        case .pro: return "Pro"
        case .profile: return "Profil"
        }
    }
}

struct BottomNavigation: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        VStack(spacing: 0) {
            // Top Border
            Rectangle()
                .fill(Color(hex: "#E5E3DE"))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach([HomeTab.home, .looks, .pro, .profile], id: \.label) { tab in
                    BottomNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.top, 14)
            .frame(height: 85)
            .background(Color.white)
        }
    }
}

struct BottomNavItem: View {
    let tab: HomeTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        Spacer()
        BottomNavigation(selectedTab: .constant(.home))
    }
    .background(Color.bgPrimary)
}
