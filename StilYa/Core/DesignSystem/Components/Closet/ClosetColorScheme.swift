//
//  ClosetColorScheme.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 24.03.2026.
//

import SwiftUI

// MARK: - Color Option Enum

enum ClosetColorOption: String, CaseIterable, Identifiable {
    case darkWood
    case lightWood
    case white
    case black
    case navy
    case green
    case pink
    case yellow
    case purple
    case red

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .darkWood: return "onboarding.closetColor.darkWood"
        case .lightWood: return "onboarding.closetColor.lightWood"
        case .white: return "onboarding.closetColor.white"
        case .black: return "onboarding.closetColor.black"
        case .navy: return "onboarding.closetColor.navy"
        case .green: return "onboarding.closetColor.green"
        case .pink: return "onboarding.closetColor.pink"
        case .yellow: return "onboarding.closetColor.yellow"
        case .purple: return "onboarding.closetColor.purple"
        case .red: return "onboarding.closetColor.red"
        }
    }

    var displayName: String {
        LocalizationManager.shared.localized(displayNameKey)
    }

    /// The representative tint color (frameMid) for navigation bar back buttons etc.
    var tintColor: Color {
        ClosetColorScheme.scheme(for: self).frameMid
    }

    /// Resolve from optional rawValue with darkWood fallback
    static func tintColor(for rawValue: String?) -> Color {
        (ClosetColorOption(rawValue: rawValue ?? "") ?? .darkWood).tintColor
    }
}

// MARK: - Color Scheme

struct ClosetColorScheme {
    // Frame colors (light → dark gradient)
    let frameLight: Color
    let frameMid: Color
    let frameDark: Color

    // Door panel colors
    let doorLight: Color
    let doorMid: Color
    let doorDark: Color

    // Panel inset colors
    let panelLight: Color
    let panelDark: Color

    // Interior
    let interior: Color
    let interiorDark: Color

    // Hardware
    let brass: Color
    let brassLight: Color

    // Accents
    let border: Color
    let shelf: Color
    let foot: Color
    let footDark: Color
    let crown: Color
    let keyhole: Color

    // MARK: - Presets

    static func scheme(for option: ClosetColorOption) -> ClosetColorScheme {
        switch option {
        case .darkWood: return darkWoodScheme
        case .lightWood: return lightWoodScheme
        case .white: return whiteScheme
        case .black: return blackScheme
        case .navy: return navyScheme
        case .green: return greenScheme
        case .pink: return pinkScheme
        case .yellow: return yellowScheme
        case .purple: return purpleScheme
        case .red: return redScheme
        }
    }

    static func scheme(for rawValue: String?) -> ClosetColorScheme {
        guard let raw = rawValue, let option = ClosetColorOption(rawValue: raw) else {
            return darkWoodScheme
        }
        return scheme(for: option)
    }

    // MARK: - Dark Wood (Default)

    static let darkWoodScheme = ClosetColorScheme(
        frameLight: Color(hex: "#9C8260"),
        frameMid: Color(hex: "#8B7355"),
        frameDark: Color(hex: "#7A6348"),
        doorLight: Color(hex: "#B09A72"),
        doorMid: Color(hex: "#9C8260"),
        doorDark: Color(hex: "#7A6348"),
        panelLight: Color(hex: "#A89470"),
        panelDark: Color(hex: "#97835A"),
        interior: Color(hex: "#2A2520"),
        interiorDark: Color(hex: "#1E1B17"),
        brass: Color(hex: "#8B7355"),
        brassLight: Color(hex: "#A89470"),
        border: Color(hex: "#A0875C"),
        shelf: Color(hex: "#6B5640"),
        foot: Color(hex: "#8B7355"),
        footDark: Color(hex: "#6B5640"),
        crown: Color(hex: "#B09A72"),
        keyhole: Color(hex: "#6B5640")
    )

    // MARK: - Light Wood

    static let lightWoodScheme = ClosetColorScheme(
        frameLight: Color(hex: "#D4BA91"),
        frameMid: Color(hex: "#C8A87A"),
        frameDark: Color(hex: "#B8956A"),
        doorLight: Color(hex: "#E0CCA0"),
        doorMid: Color(hex: "#D4BA91"),
        doorDark: Color(hex: "#B8956A"),
        panelLight: Color(hex: "#D8C090"),
        panelDark: Color(hex: "#CCAD7A"),
        interior: Color(hex: "#3A2A1A"),
        interiorDark: Color(hex: "#2E2015"),
        brass: Color(hex: "#C8A87A"),
        brassLight: Color(hex: "#D8C090"),
        border: Color(hex: "#C8A870"),
        shelf: Color(hex: "#A08550"),
        foot: Color(hex: "#C8A87A"),
        footDark: Color(hex: "#A08550"),
        crown: Color(hex: "#E0CCA0"),
        keyhole: Color(hex: "#A08550")
    )

    // MARK: - White

    static let whiteScheme = ClosetColorScheme(
        frameLight: Color(hex: "#F0EBE4"),
        frameMid: Color(hex: "#E8E1D8"),
        frameDark: Color(hex: "#DDD6CC"),
        doorLight: Color(hex: "#F5F0E9"),
        doorMid: Color(hex: "#F0EBE4"),
        doorDark: Color(hex: "#DDD6CC"),
        panelLight: Color(hex: "#EDE7DE"),
        panelDark: Color(hex: "#E5DDD3"),
        interior: Color(hex: "#3A3A3A"),
        interiorDark: Color(hex: "#2E2E2E"),
        brass: Color(hex: "#E8E1D8"),
        brassLight: Color(hex: "#EDE7DE"),
        border: Color(hex: "#D5CFC5"),
        shelf: Color(hex: "#C8C0B5"),
        foot: Color(hex: "#E8E1D8"),
        footDark: Color(hex: "#C8C0B5"),
        crown: Color(hex: "#F5F0E9"),
        keyhole: Color(hex: "#B0AAA0")
    )

    // MARK: - Black

    static let blackScheme = ClosetColorScheme(
        frameLight: Color(hex: "#4A4A4A"),
        frameMid: Color(hex: "#3A3A3A"),
        frameDark: Color(hex: "#2A2A2A"),
        doorLight: Color(hex: "#555555"),
        doorMid: Color(hex: "#4A4A4A"),
        doorDark: Color(hex: "#2A2A2A"),
        panelLight: Color(hex: "#484848"),
        panelDark: Color(hex: "#3C3C3C"),
        interior: Color(hex: "#1A1A1A"),
        interiorDark: Color(hex: "#121212"),
        brass: Color(hex: "#4A4A4A"),
        brassLight: Color(hex: "#555555"),
        border: Color(hex: "#5A5A5A"),
        shelf: Color(hex: "#383838"),
        foot: Color(hex: "#3A3A3A"),
        footDark: Color(hex: "#282828"),
        crown: Color(hex: "#555555"),
        keyhole: Color(hex: "#333333")
    )

    // MARK: - Navy

    static let navyScheme = ClosetColorScheme(
        frameLight: Color(hex: "#3A5078"),
        frameMid: Color(hex: "#2E4060"),
        frameDark: Color(hex: "#223050"),
        doorLight: Color(hex: "#4A6088"),
        doorMid: Color(hex: "#3A5078"),
        doorDark: Color(hex: "#223050"),
        panelLight: Color(hex: "#3E5575"),
        panelDark: Color(hex: "#324565"),
        interior: Color(hex: "#141E2E"),
        interiorDark: Color(hex: "#0E1622"),
        brass: Color(hex: "#3A5078"),
        brassLight: Color(hex: "#4A6088"),
        border: Color(hex: "#4A6080"),
        shelf: Color(hex: "#283A52"),
        foot: Color(hex: "#2E4060"),
        footDark: Color(hex: "#1E3048"),
        crown: Color(hex: "#4A6088"),
        keyhole: Color(hex: "#1E3048")
    )

    // MARK: - Green (Sage)

    static let greenScheme = ClosetColorScheme(
        frameLight: Color(hex: "#6DA87A"),
        frameMid: Color(hex: "#5C9668"),
        frameDark: Color(hex: "#4A8558"),
        doorLight: Color(hex: "#7DB88A"),
        doorMid: Color(hex: "#6DA87A"),
        doorDark: Color(hex: "#4A8558"),
        panelLight: Color(hex: "#72AC7E"),
        panelDark: Color(hex: "#60A06C"),
        interior: Color(hex: "#1E3525"),
        interiorDark: Color(hex: "#17291D"),
        brass: Color(hex: "#5C9668"),
        brassLight: Color(hex: "#6DA87A"),
        border: Color(hex: "#7DB88A"),
        shelf: Color(hex: "#3D7048"),
        foot: Color(hex: "#5C9668"),
        footDark: Color(hex: "#3D7048"),
        crown: Color(hex: "#7DB88A"),
        keyhole: Color(hex: "#3D7048")
    )

    // MARK: - Pink

    static let pinkScheme = ClosetColorScheme(
        frameLight: Color(hex: "#D4A0A8"),
        frameMid: Color(hex: "#C48B95"),
        frameDark: Color(hex: "#B07882"),
        doorLight: Color(hex: "#E0B0B8"),
        doorMid: Color(hex: "#D4A0A8"),
        doorDark: Color(hex: "#B07882"),
        panelLight: Color(hex: "#D8A5AD"),
        panelDark: Color(hex: "#CC959F"),
        interior: Color(hex: "#3D1F28"),
        interiorDark: Color(hex: "#30181F"),
        brass: Color(hex: "#C48B95"),
        brassLight: Color(hex: "#D4A0A8"),
        border: Color(hex: "#D8A8B0"),
        shelf: Color(hex: "#A06878"),
        foot: Color(hex: "#C48B95"),
        footDark: Color(hex: "#A06878"),
        crown: Color(hex: "#E0B0B8"),
        keyhole: Color(hex: "#A06878")
    )

    // MARK: - Yellow (Mustard)

    static let yellowScheme = ClosetColorScheme(
        frameLight: Color(hex: "#D4B44A"),
        frameMid: Color(hex: "#C4A038"),
        frameDark: Color(hex: "#A8882E"),
        doorLight: Color(hex: "#E0C458"),
        doorMid: Color(hex: "#D4B44A"),
        doorDark: Color(hex: "#A8882E"),
        panelLight: Color(hex: "#D8B848"),
        panelDark: Color(hex: "#CCA83C"),
        interior: Color(hex: "#3A3018"),
        interiorDark: Color(hex: "#2E2612"),
        brass: Color(hex: "#C4A038"),
        brassLight: Color(hex: "#D4B44A"),
        border: Color(hex: "#D8BC50"),
        shelf: Color(hex: "#907828"),
        foot: Color(hex: "#C4A038"),
        footDark: Color(hex: "#907828"),
        crown: Color(hex: "#E0C458"),
        keyhole: Color(hex: "#907828")
    )

    // MARK: - Purple (Plum)

    static let purpleScheme = ClosetColorScheme(
        frameLight: Color(hex: "#8A6898"),
        frameMid: Color(hex: "#785888"),
        frameDark: Color(hex: "#664878"),
        doorLight: Color(hex: "#9A78A8"),
        doorMid: Color(hex: "#8A6898"),
        doorDark: Color(hex: "#664878"),
        panelLight: Color(hex: "#8E6C9C"),
        panelDark: Color(hex: "#7E5C8C"),
        interior: Color(hex: "#28182E"),
        interiorDark: Color(hex: "#1E1222"),
        brass: Color(hex: "#785888"),
        brassLight: Color(hex: "#8A6898"),
        border: Color(hex: "#9A78A8"),
        shelf: Color(hex: "#584068"),
        foot: Color(hex: "#785888"),
        footDark: Color(hex: "#584068"),
        crown: Color(hex: "#9A78A8"),
        keyhole: Color(hex: "#584068")
    )

    // MARK: - Red (Burgundy)

    static let redScheme = ClosetColorScheme(
        frameLight: Color(hex: "#A84848"),
        frameMid: Color(hex: "#963838"),
        frameDark: Color(hex: "#802828"),
        doorLight: Color(hex: "#B85858"),
        doorMid: Color(hex: "#A84848"),
        doorDark: Color(hex: "#802828"),
        panelLight: Color(hex: "#AC4C4C"),
        panelDark: Color(hex: "#9C3C3C"),
        interior: Color(hex: "#2E1818"),
        interiorDark: Color(hex: "#221212"),
        brass: Color(hex: "#963838"),
        brassLight: Color(hex: "#A84848"),
        border: Color(hex: "#B85858"),
        shelf: Color(hex: "#702828"),
        foot: Color(hex: "#963838"),
        footDark: Color(hex: "#702828"),
        crown: Color(hex: "#B85858"),
        keyhole: Color(hex: "#702828")
    )
}
