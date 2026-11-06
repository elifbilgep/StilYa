//
//  DebugLogManager.swift
//  StilYa
//
//  In-app log viewer — ring buffer ile son 500 log satırını tutar.
//  Shake-to-debug ve 5x tap sadece DEBUG build'lerde çalışır.
//

import Foundation
import SwiftUI
#if DEBUG
import CoreMotion
#endif

// MARK: - Log Entry

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: LogCategory
    let message: String

    enum LogCategory: String, CaseIterable {
        case auth = "Auth"
        case ai = "AI"
        case network = "Network"
        case encryption = "E2E"
        case storage = "Storage"
        case credits = "Credits"
        case general = "General"

        var icon: String {
            switch self {
            case .auth: return "person.badge.key"
            case .ai: return "sparkles"
            case .network: return "wifi"
            case .encryption: return "lock.shield"
            case .storage: return "externaldrive"
            case .credits: return "star.circle"
            case .general: return "text.alignleft"
            }
        }

        var color: Color {
            switch self {
            case .auth: return .blue
            case .ai: return .purple
            case .network: return .orange
            case .encryption: return .green
            case .storage: return .cyan
            case .credits: return .yellow
            case .general: return .gray
            }
        }
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

// MARK: - DebugLogManager

@Observable
final class DebugLogManager {
    static let shared = DebugLogManager()

    private(set) var entries: [DebugLogEntry] = []
    private let maxEntries = 500
    private let queue = DispatchQueue(label: "com.stilya.debuglog", qos: .utility)

    private init() {}

    func log(_ message: String, category: DebugLogEntry.LogCategory = .general) {
        let entry = DebugLogEntry(timestamp: Date(), category: category, message: message)
        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.entries.append(entry)
                if let count = self?.entries.count, count > (self?.maxEntries ?? 500) {
                    self?.entries.removeFirst(count - (self?.maxEntries ?? 500))
                }
            }
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// Tüm logları tek string olarak kopyalama için
    var exportText: String {
        entries.map { "[\($0.formattedTime)] [\($0.category.rawValue)] \($0.message)" }
            .joined(separator: "\n")
    }
}

// MARK: - Global Shortcut

/// Uygulama genelinde kolay log ekleme — sadece DEBUG build'lerde çalışır
func appLog(_ message: String, category: DebugLogEntry.LogCategory = .general) {
    #if DEBUG
    DebugLogManager.shared.log(message, category: category)
    #endif
}

// MARK: - Shake Detection (DEBUG only)

#if DEBUG
/// Accelerometer ile shake algılar — UIWindow/SceneDelegate gerekmez
@Observable
final class ShakeDetector {
    static let shared = ShakeDetector()

    private let motionManager = CMMotionManager()
    private var lastShakeTime: Date = .distantPast
    private var isMonitoring = false

    private init() {}

    func startMonitoring() {
        guard !isMonitoring, motionManager.isAccelerometerAvailable else { return }
        isMonitoring = true
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data = data, let self = self else { return }
            let g = data.acceleration
            let magnitude = sqrt(g.x * g.x + g.y * g.y + g.z * g.z)
            if magnitude > 2.5 {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > 1.5 {
                    self.lastShakeTime = now
                    NotificationCenter.default.post(name: .deviceDidShake, object: nil)
                }
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// Shake'te DebugLogView açan modifier
struct ShakeToDebugModifier: ViewModifier {
    @State private var showDebugLogs = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                ShakeDetector.shared.startMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                if !showDebugLogs {
                    showDebugLogs = true
                }
            }
            .fullScreenCover(isPresented: $showDebugLogs) {
                DebugLogView(onClose: { showDebugLogs = false })
            }
    }
}

extension View {
    func shakeToDebug() -> some View {
        modifier(ShakeToDebugModifier())
    }
}
#endif
