//
//  LocalizationManager.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 15.02.2026.
//

import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable {
    case turkish = "tr"
    case english = "en"

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }

    var flag: String {
        switch self {
        case .turkish: return "🇹🇷"
        case .english: return "🇬🇧"
        }
    }

    var locale: Locale {
        switch self {
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        }
    }
}

@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            loadStrings()
        }
    }

    private var strings: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: saved) {
            // Kullanıcı daha önce manuel dil seçmiş
            currentLanguage = language
        } else {
            // İlk açılış: Cihazın sistem dilini kullan
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = deviceLanguage.hasPrefix("tr") ? .turkish : .english
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
        loadStrings()
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        NotificationCenter.default.post(name: NSNotification.Name("app_language_changed"), object: nil)
    }

    func localized(_ key: String) -> String {
        strings[key] ?? key
    }

    func localized(_ key: String, _ args: [CVarArg]) -> String {
        let format = strings[key] ?? key
        return String(format: format, arguments: args)
    }

    private func loadStrings() {
        let filename = currentLanguage.rawValue
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: nil),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            #if DEBUG
            print("⚠️ [Localization] Failed to load \(filename).json")
            #endif
            return
        }
        strings = dict
    }
}
