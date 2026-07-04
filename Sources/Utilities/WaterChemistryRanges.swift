//
//  WaterChemistryRanges.swift
//  HotTub
//

import SwiftUI

enum WaterChemistryReadingStatus {
    case inRange
    case caution
    case attention
}

enum WaterChemistryRanges {
    static let phIdeal: ClosedRange<Double> = 7.2 ... 7.8
    static let chlorineIdeal: ClosedRange<Double> = 1.0 ... 3.0
    static let bromineIdeal: ClosedRange<Double> = 3.0 ... 5.0

    static func phStatus(_ value: Double) -> WaterChemistryReadingStatus {
        if phIdeal.contains(value) { return .inRange }
        if value >= 7.0, value <= 8.0 { return .caution }
        return .attention
    }

    static func chlorineStatus(_ value: Double) -> WaterChemistryReadingStatus {
        if chlorineIdeal.contains(value) { return .inRange }
        if value >= 0.5, value <= 5.0 { return .caution }
        return .attention
    }

    static func bromineStatus(_ value: Double) -> WaterChemistryReadingStatus {
        if bromineIdeal.contains(value) { return .inRange }
        if value >= 2.0, value <= 6.0 { return .caution }
        return .attention
    }

    static func statusColor(_ status: WaterChemistryReadingStatus, palette: AppPalette) -> Color {
        switch status {
        case .inRange: palette.color(.accentGreen)
        case .caution: palette.color(.accentOrange)
        case .attention: palette.color(.accentRed)
        }
    }
}
