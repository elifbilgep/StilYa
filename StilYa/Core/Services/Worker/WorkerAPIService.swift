//
//  WorkerAPIService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 27.02.2026.
//  Cloudflare Worker API client for server-side credit/subscription operations.
//

import Foundation
import DeviceCheck
import FirebaseAuth
import FirebaseAppCheck

// MARK: - Worker API Errors

enum WorkerAPIError: Error, LocalizedError {
    case unauthorized
    case insufficientCredits(required: Int)
    case userNotFound
    case purchaseNotFound
    case networkError(Error)
    case serverError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Oturum süresi doldu, lütfen tekrar giriş yapın"
        case .insufficientCredits(let required):
            return "Yeterli krediniz yok. Bu işlem için \(required) kredi gerekiyor."
        case .userNotFound:
            return "Kullanıcı bulunamadı"
        case .purchaseNotFound:
            return "Satın alma işlemi doğrulanamadı"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        case .serverError(let message):
            return "Sunucu hatası: \(message)"
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı"
        }
    }
}

// MARK: - Response Models

struct SyncProResponse: Codable {
    let success: Bool?
    let isPro: Bool?
    let credits: Int?
    let error: String?
    let detail: String?
}

struct VerifyPurchaseResponse: Codable {
    let success: Bool?
    let credits: Int?
    let added: Int?
    let duplicate: Bool?
    let error: String?
}

struct ProcessReferralResponse: Codable {
    let success: Bool?
    let bonusCredits: Int?
    let error: String?
}

struct DeviceCheckResponse: Codable {
    let allowed: Bool?
    let freeCreditsAlreadyClaimed: Bool?
    let error: String?
    let blockedUntil: String?
}

struct AccountDeleteResponse: Codable {
    let success: Bool?
    let error: String?
}

struct RewardAdResponse: Codable {
    let success: Bool?
    let credits: Int?
    let dailyAdsRemaining: Int?
    let error: String?
}

struct GetCreditsResponse: Codable {
    let credits: Int?
    let breakdown: CreditBreakdown?
    let isPro: Bool?
    let error: String?

    struct CreditBreakdown: Codable {
        let free: Int
        let purchased: Int
        let pro: Int
    }
}

struct RemoteConfig: Codable {
    let appEnabled: Bool?
    let maintenanceMessage: String?
    let modelPhotoEnabled: Bool?
    let freeWeeklyCredits: Int?
    let trialCredits: Int?
    let proWeeklyCredits: Int?
}

// MARK: - WorkerAPIService

class WorkerAPIService {
    static let shared = WorkerAPIService()

    private var baseURL: String { Configuration.shared.apiBaseURL }
    private let session: URLSession

    // Remote config cache (TTL: 5 dakika)
    private var cachedConfig: RemoteConfig?
    private var configCacheDate: Date?
    private let configCacheTTL: TimeInterval = 300 // 5 min

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Public Config (no auth)

    func fetchRemoteConfig(forceRefresh: Bool = false) async -> RemoteConfig {
        // Cache'den dön (TTL dolmamışsa)
        if !forceRefresh, let cached = cachedConfig, let cacheDate = configCacheDate,
           Date().timeIntervalSince(cacheDate) < configCacheTTL {
            return cached
        }

        guard let url = URL(string: "\(baseURL)/api/config") else {
            return cachedConfig ?? RemoteConfig(appEnabled: true, maintenanceMessage: nil, modelPhotoEnabled: true, freeWeeklyCredits: nil, trialCredits: nil, proWeeklyCredits: nil)
        }
        do {
            let (data, _) = try await session.data(from: url)
            let config = try JSONDecoder().decode(RemoteConfig.self, from: data)
            cachedConfig = config
            configCacheDate = Date()
            return config
        } catch {
            return cachedConfig ?? RemoteConfig(appEnabled: true, maintenanceMessage: nil, modelPhotoEnabled: true, freeWeeklyCredits: nil, trialCredits: nil, proWeeklyCredits: nil)
        }
    }

    // MARK: - Public Trends (no auth)

    func fetchTrendCollections(gender: String? = nil, page: Int = 1, limit: Int = 10) async -> TrendsResponse {
        var components = URLComponents(string: "\(baseURL)/api/trends")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let gender { queryItems.append(URLQueryItem(name: "gender", value: gender)) }
        components.queryItems = queryItems
        guard let url = components.url else {
            return TrendsResponse(collections: [], totalCount: 0, page: page, limit: limit, hasMore: false)
        }
        do {
            let (data, _) = try await session.data(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TrendsResponse.self, from: data)
        } catch {
            print("[WorkerAPI] fetchTrendCollections error: \(error)")
            return TrendsResponse(collections: [], totalCount: 0, page: page, limit: limit, hasMore: false)
        }
    }

    // MARK: - Auth Headers

    private func makeAuthenticatedRequest(path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw WorkerAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Firebase Auth token
        guard let user = Auth.auth().currentUser else {
            throw WorkerAPIError.unauthorized
        }
        let idToken = try await user.getIDToken()
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        // App Check token
        if let appCheckToken = try? await AppCheck.appCheck().token(forcingRefresh: false).token {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        // Body
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkerAPIError.invalidResponse
        }

        appLog("\(method) \(path) → \(httpResponse.statusCode)", category: .network)

        return (data, httpResponse)
    }

    // MARK: - Public API

    /// Sync Pro status from RevenueCat → Firestore (via Worker)
    @discardableResult
    func syncPro() async throws -> SyncProResponse {
        let (data, httpResponse) = try await makeAuthenticatedRequest(path: "/api/sync-pro", method: "POST")

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        let response = try JSONDecoder().decode(SyncProResponse.self, from: data)

        if httpResponse.statusCode == 404 {
            throw WorkerAPIError.userNotFound
        }

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            let rawBody = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ [WorkerAPI] syncPro failed: \(response.error ?? "unknown") | detail: \(response.detail ?? "none") | HTTP: \(httpResponse.statusCode)")
            print("❌ [WorkerAPI] syncPro raw response: \(rawBody)")
            #endif
            throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
        }

        return response
    }

    /// Verify a credit pack purchase via RevenueCat and add credits
    @discardableResult
    func verifyPurchase(productId: String, transactionId: String?) async throws -> VerifyPurchaseResponse {
        var body: [String: Any] = ["productId": productId]
        if let txId = transactionId {
            body["transactionId"] = txId
        }

        let (data, httpResponse) = try await makeAuthenticatedRequest(
            path: "/api/purchase/verify",
            method: "POST",
            body: body
        )

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        let response = try JSONDecoder().decode(VerifyPurchaseResponse.self, from: data)

        if httpResponse.statusCode == 404 {
            throw WorkerAPIError.purchaseNotFound
        }

        guard httpResponse.statusCode == 200 else {
            throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
        }

        // Satın alma sonrası güncel krediyi UI'a bildir
        if let credits = response.credits {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .creditsDidUpdate,
                    object: nil,
                    userInfo: ["credits": credits]
                )
            }
        }

        return response
    }

    /// Process a referral code (server-side validation + credit addition)
    @discardableResult
    func processReferral(code: String) async throws -> ProcessReferralResponse {
        let (data, httpResponse) = try await makeAuthenticatedRequest(
            path: "/api/referral/process",
            method: "POST",
            body: ["code": code]
        )

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        let response = try JSONDecoder().decode(ProcessReferralResponse.self, from: data)

        guard httpResponse.statusCode == 200 else {
            throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
        }

        return response
    }

    /// Get current credit balance from Worker
    func getCredits() async throws -> GetCreditsResponse {
        let (data, httpResponse) = try await makeAuthenticatedRequest(path: "/api/credits")

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        let response = try JSONDecoder().decode(GetCreditsResponse.self, from: data)

        guard httpResponse.statusCode == 200 else {
            throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
        }

        return response
    }

    // MARK: - Rewarded Ads

    /// Claim rewarded ad credit (server-side daily limit check)
    @discardableResult
    func rewardAdCredit() async throws -> RewardAdResponse {
        let (data, httpResponse) = try await makeAuthenticatedRequest(
            path: "/api/ads/reward",
            method: "POST"
        )

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        let response = try JSONDecoder().decode(RewardAdResponse.self, from: data)

        guard httpResponse.statusCode == 200 else {
            throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
        }

        // Update UI with new credit balance
        if let credits = response.credits {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .creditsDidUpdate,
                    object: nil,
                    userInfo: ["credits": credits]
                )
            }
        }

        return response
    }

    // MARK: - Debug

    #if DEBUG
    /// Reset all credits to 0 (debug only — requires IS_DEBUG=true on worker)
    func debugResetCredits() async throws {
        let (_, httpResponse) = try await makeAuthenticatedRequest(path: "/api/debug/reset-credits", method: "POST")
        guard httpResponse.statusCode == 200 else {
            throw WorkerAPIError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
    #endif

    // MARK: - Device Abuse Prevention

    /// Generate Apple DeviceCheck token (base64 encoded)
    private func getDeviceToken() async -> String? {
        guard DCDevice.current.isSupported else { return nil }
        do {
            let tokenData = try await DCDevice.current.generateToken()
            return tokenData.base64EncodedString()
        } catch {
            #if DEBUG
            print("⚠️ [DeviceCheck] Token generation failed: \(error)")
            #endif
            return nil
        }
    }

    /// Check if device is allowed to create a new account (abuse prevention)
    func checkDevice(fingerprint: String) async throws -> DeviceCheckResponse {
        var bodyDict: [String: String] = ["deviceFingerprint": fingerprint]
        if let token = await getDeviceToken() {
            bodyDict["deviceToken"] = token
        }

        let (data, httpResponse) = try await makeAuthenticatedRequest(
            path: "/api/device/check",
            method: "POST",
            body: bodyDict
        )

        // 403 = blocked device, still parse response for error message
        let response = try JSONDecoder().decode(DeviceCheckResponse.self, from: data)

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        // 403 is expected for blocked devices — return the response (allowed: false)
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 200 {
            return response
        }

        throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
    }

    /// Notify Worker that this device is deleting its account
    @discardableResult
    func notifyAccountDeletion(fingerprint: String) async throws -> AccountDeleteResponse {
        var bodyDict: [String: String] = ["deviceFingerprint": fingerprint]
        if let token = await getDeviceToken() {
            bodyDict["deviceToken"] = token
        }

        let (data, httpResponse) = try await makeAuthenticatedRequest(
            path: "/api/account/delete",
            method: "POST",
            body: bodyDict
        )

        if httpResponse.statusCode == 401 {
            throw WorkerAPIError.unauthorized
        }

        let response = try JSONDecoder().decode(AccountDeleteResponse.self, from: data)

        guard httpResponse.statusCode == 200 else {
            throw WorkerAPIError.serverError(response.error ?? "HTTP \(httpResponse.statusCode)")
        }

        return response
    }
}

// MARK: - Notification for credit updates

extension Notification.Name {
    static let creditsDidUpdate = Notification.Name("creditsDidUpdate")
    static let proStatusDidChange = Notification.Name("proStatusDidChange")
    static let openClosetDeepLink = Notification.Name("openClosetDeepLink")
}
