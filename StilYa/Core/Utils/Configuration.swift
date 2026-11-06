//
//  Configuration.swift
//  StilYa
//
//  Build-time configuration. Values come from Config/Base.xcconfig and the
//  gitignored Config/Secrets.xcconfig, surfaced through Info.plist.
//

import Foundation

final class Configuration {
    static let shared = Configuration()

    /// Base URL of the StilYa Cloudflare Worker (the only backend the app talks to).
    /// The worker holds FAL_KEY and every other secret.
    let apiBaseURL: String

    /// RevenueCat public SDK key. Empty → purchases disabled.
    let revenueCatAPIKey: String

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let base = (info["STILYA_API_BASE_URL"] as? String) ?? ""
        apiBaseURL = base.isEmpty ? "http://localhost:8787" : base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        revenueCatAPIKey = (info["REVENUECAT_API_KEY"] as? String) ?? ""
    }
}
