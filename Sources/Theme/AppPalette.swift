//
//  AppPalette.swift
//  HotTub
//
//  Semantic colours from ios-colour-example-page.html & ios-colour-schema 2.html.
//

import SwiftUI

enum PaletteToken: CaseIterable {
    case backgroundPrimary
    case backgroundSecondary
    case backgroundTertiary
    case separator
    case textPrimary
    case textSecondary
    case textTertiary
    case accentBlue
    case accentGreen
    case accentRed
    case accentOrange
    case accentYellow
    case accentIndigo
    case accentTeal
    case accentPink
    case surfaceCard
    case surfaceMuted
    case statusSuccessFill
    case statusSuccessBorder
    case statusSuccessText
    case statusWarningFill
    case statusWarningBorder
    case statusWarningText
    case statusErrorFill
    case statusErrorBorder
    case statusErrorText
    case tagBlueFill
    case tagGreenFill
    case tagOrangeFill
    case tagPinkFill
    case heroGradientStart
    case heroGradientEnd
    case heroEmptyStart
    case heroEmptyEnd
    case onAccent
    case scrim
}

struct AppPalette {
    let colorScheme: ColorScheme

    func color(_ token: PaletteToken) -> Color {
        let isDark = colorScheme == .dark
        switch token {
        case .backgroundPrimary:
            return isDark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
        case .backgroundSecondary:
            return isDark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF2F2F7)
        case .backgroundTertiary:
            return isDark ? Color(hex: 0x2C2C2E) : Color(hex: 0xFFFFFF)
        case .separator:
            return isDark ? Color(hex: 0x3A3A3C) : Color(hex: 0xC6C6C8)
        case .textPrimary:
            return isDark ? Color(hex: 0xFFFFFF) : Color(hex: 0x000000)
        case .textSecondary:
            return isDark
                ? Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.72)
                : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.72)
        case .textTertiary:
            return isDark
                ? Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.48)
                : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.48)
        case .accentBlue:
            return Color(hex: 0x007AFF)
        case .accentGreen:
            return Color(hex: 0x34C759)
        case .accentRed:
            return Color(hex: 0xFF3B30)
        case .accentOrange:
            return Color(hex: 0xE68600)
        case .accentYellow:
            return Color(hex: 0xFFCC00)
        case .accentIndigo:
            return Color(hex: 0x5856D6)
        case .accentTeal:
            return Color(hex: 0x5AC8FA)
        case .accentPink:
            return Color(hex: 0xFF2D55)
        case .surfaceCard:
            return isDark ? Color(hex: 0x1C1C1E) : Color(hex: 0xFFFFFF)
        case .surfaceMuted:
            return isDark ? Color(hex: 0x2C2C2E) : Color(hex: 0xF2F2F7)
        case .statusSuccessFill:
            return Color(hex: 0x34C759).opacity(0.12)
        case .statusSuccessBorder:
            return Color(hex: 0x34C759).opacity(0.35)
        case .statusSuccessText:
            return Color(hex: 0x1E6D34)
        case .statusWarningFill:
            return Color(hex: 0xE68600).opacity(0.12)
        case .statusWarningBorder:
            return Color(hex: 0xE68600).opacity(0.35)
        case .statusWarningText:
            return Color(hex: 0x8A4B00)
        case .statusErrorFill:
            return Color(hex: 0xFF3B30).opacity(0.12)
        case .statusErrorBorder:
            return Color(hex: 0xFF3B30).opacity(0.35)
        case .statusErrorText:
            return Color(hex: 0x9A1F17)
        case .tagBlueFill:
            return Color(hex: 0x007AFF).opacity(0.12)
        case .tagGreenFill:
            return Color(hex: 0x34C759).opacity(0.12)
        case .tagOrangeFill:
            return Color(hex: 0xE68600).opacity(0.12)
        case .tagPinkFill:
            return Color(hex: 0xFF2D55).opacity(0.12)
        case .heroGradientStart:
            return Color(hex: 0x5AC8FA).opacity(0.35)
        case .heroGradientEnd:
            return Color(hex: 0x5856D6).opacity(0.45)
        case .heroEmptyStart:
            return Color(hex: 0x6B9BD1)
        case .heroEmptyEnd:
            return Color(hex: 0x8BA8C7)
        case .onAccent:
            return Color(hex: 0xFFFFFF)
        case .scrim:
            return Color.black.opacity(0.5)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette(colorScheme: .light)
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

extension View {
    func appPalette(_ scheme: ColorScheme) -> some View {
        environment(\.appPalette, AppPalette(colorScheme: scheme))
    }
}
