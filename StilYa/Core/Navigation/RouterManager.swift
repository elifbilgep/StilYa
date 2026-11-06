//
//  RouterManager.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 17.12.2025.
//

import SwiftUI
import Combine

// MARK: - Destination Enum
enum Destination: Codable, Hashable {
    // Auth Flow
    case welcome
    case signUp
    case signIn

    // Onboarding Flow
    case onboarding

    // Main App
    case home
    case looks
    case trendMagazine
    case dressUp
    case profile
}

// MARK: - Router Manager
final class RouterManager: ObservableObject {
    @Published var path = NavigationPath()

    // MARK: - Navigation Methods
    func push(_ destination: Destination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func replace(with destination: Destination) {
        path = NavigationPath()
        path.append(destination)
    }

    /// Push without NavigationStack animation (splash → app gibi geçişler için)
    func pushWithoutAnimation(_ destination: Destination) {
        var transaction = Transaction(animation: .none)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            path.append(destination)
        }
    }
}
