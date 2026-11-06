//
//  WeatherTipProvider.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import SwiftUI
import CoreLocation
import WeatherKit

enum WeatherMood: String {
    case sunny      // hot & clear
    case warm       // pleasant
    case cool       // layering weather
    case cold       // bundle up
    case rainy      // wet
    case snowy      // winter
    case fallback   // no weather data

    var accentColor: Color {
        switch self {
        case .sunny:   return Color(hex: "#E8A317") // warm amber
        case .warm:    return Color(hex: "#6BAF6B") // soft green
        case .cool:    return Color(hex: "#7BA7C9") // sky blue
        case .cold:    return Color(hex: "#8B9DC3") // steel blue
        case .rainy:   return Color(hex: "#7393A7") // rain grey-blue
        case .snowy:   return Color(hex: "#A3B5C7") // icy blue
        case .fallback: return Color.proGold
        }
    }

    var bgColor: Color {
        switch self {
        case .sunny:   return Color(hex: "#FFF8E7") // warm cream
        case .warm:    return Color(hex: "#EEFAEE") // mint
        case .cool:    return Color(hex: "#EBF3FA") // light sky
        case .cold:    return Color(hex: "#EDF0F7") // lavender
        case .rainy:   return Color(hex: "#ECF1F5") // misty
        case .snowy:   return Color(hex: "#F0F4F8") // frost
        case .fallback: return Color.proGoldLight
        }
    }
}

@Observable
final class WeatherTipProvider {
    var tip: String
    var iconName: String = "sparkles"
    var temperature: String? // e.g. "18°"
    var hasWeatherData = false
    var mood: WeatherMood = .fallback
    var attributionLogoURL: URL?
    var attributionLegalURL: URL?
    var locationDenied = false

    private var hasFetched = false
    private var locationDelegate: LocationDelegate?
    private var lastCondition: WeatherCondition?
    private var lastTemperature: Double?
    nonisolated(unsafe) private var languageObserver: Any?

    init() {
        self.tip = Self.randomFallbackTip()

        // Dil değiştiğinde tip'i yeniden hesapla
        languageObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("app_language_changed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshTip()
        }
    }

    deinit {
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private static func randomFallbackTip() -> String {
        let fallbackTips = [
            L10n.tryonTipsPlainColors,
            L10n.tryonTipsAccessoryCompletes,
            L10n.tryonTipsRightSize,
            L10n.tryonTipsContrastColors,
            L10n.tryonTipsLessIsMore
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return fallbackTips[dayIndex % fallbackTips.count]
    }

    /// Dil değiştiğinde mevcut hava durumuna göre tip'i yeniden oluştur
    private func refreshTip() {
        if let condition = lastCondition, let temp = lastTemperature {
            updateTip(condition: condition, temperature: temp)
        } else {
            tip = Self.randomFallbackTip()
        }
    }

    func fetch() {
        guard !hasFetched else { return }
        hasFetched = true

        let delegate = LocationDelegate(
            onLocation: { [weak self] location in
                self?.handleLocation(location)
            },
            onDenied: { [weak self] in
                Task { @MainActor in
                    self?.locationDenied = true
                }
            }
        )
        self.locationDelegate = delegate
        delegate.start()
    }

    private func handleLocation(_ location: CLLocation) {
        Task { @MainActor in
            do {
                let weather = try await WeatherService.shared.weather(for: location)
                let condition = weather.currentWeather.condition
                let temp = weather.currentWeather.temperature.converted(to: .celsius).value
                temperature = "\(Int(temp.rounded()))°"
                updateTip(condition: condition, temperature: temp)
                withAnimation(.easeOut(duration: 0.4)) {
                    hasWeatherData = true
                }

                // Fetch Apple Weather attribution
                let attribution = try await WeatherService.shared.attribution
                attributionLegalURL = attribution.legalPageURL
                attributionLogoURL = attribution.combinedMarkLightURL
            } catch {
                #if DEBUG
                print("⛅ [WeatherTip] WeatherKit error: \(error)")
                #endif
                // Keep fallback tip
            }
        }
    }

    @MainActor
    private func updateTip(condition: WeatherCondition, temperature: Double) {
        lastCondition = condition
        lastTemperature = temperature

        switch condition {
        case .rain, .drizzle, .heavyRain, .thunderstorms:
            tip = L10n.weatherTipRainy
            iconName = "cloud.rain.fill"
            mood = .rainy
        case .snow, .sleet, .heavySnow, .blizzard, .freezingRain:
            tip = L10n.weatherTipSnowy
            iconName = "cloud.snow.fill"
            mood = .snowy
        case .cloudy, .mostlyCloudy:
            iconName = "cloud.fill"
            if temperature > 20 {
                tip = L10n.weatherTipWarm
                mood = .warm
            } else if temperature > 12 {
                tip = L10n.weatherTipCool
                mood = .cool
            } else {
                tip = L10n.weatherTipCold
                mood = .cold
            }
        case .partlyCloudy, .mostlyClear:
            if temperature > 28 {
                tip = L10n.weatherTipHot
                iconName = "sun.max.fill"
                mood = .sunny
            } else if temperature > 20 {
                tip = L10n.weatherTipWarm
                iconName = "cloud.sun.fill"
                mood = .warm
            } else if temperature > 12 {
                tip = L10n.weatherTipCool
                iconName = "cloud.sun.fill"
                mood = .cool
            } else {
                tip = L10n.weatherTipCold
                iconName = "cloud.fill"
                mood = .cold
            }
        case .windy, .breezy:
            tip = L10n.weatherTipCool
            iconName = "wind"
            mood = .cool
        default:
            if temperature > 28 {
                tip = L10n.weatherTipHot
                iconName = "sun.max.fill"
                mood = .sunny
            } else if temperature > 20 {
                tip = L10n.weatherTipWarm
                iconName = "sun.min.fill"
                mood = .warm
            } else if temperature > 12 {
                tip = L10n.weatherTipCool
                iconName = "cloud.sun.fill"
                mood = .cool
            } else {
                tip = L10n.weatherTipCold
                iconName = "thermometer.snowflake"
                mood = .cold
            }
        }
    }
}

// MARK: - CLLocationManager Delegate

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let onLocation: (CLLocation) -> Void
    private let onDenied: () -> Void

    init(onLocation: @escaping (CLLocation) -> Void, onDenied: @escaping () -> Void) {
        self.onLocation = onLocation
        self.onDenied = onDenied
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func start() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            onDenied()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            onDenied()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            onLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("⛅ [WeatherTip] Location error: \(error)")
        #endif
        // Keep fallback tip
    }
}
