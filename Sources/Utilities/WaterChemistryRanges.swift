//
//  WaterChemistryRanges.swift
//  HotTub
//

import SwiftUI

/// Comparison of one recorded value with a saved target range.
enum RangeStatus: Equatable {
    case below
    case within
    case above
    case unknown

    init(value: Double?, minimum: Double, maximum: Double) {
        guard let value, minimum < maximum else {
            self = .unknown
            return
        }
        if value < minimum {
            self = .below
        } else if value > maximum {
            self = .above
        } else {
            self = .within
        }
    }

    init(value: Double?, target: ClosedRange<Double>) {
        self.init(value: value, minimum: target.lowerBound, maximum: target.upperBound)
    }

    /// Short label shown beside the reading.
    var shortLabel: String {
        switch self {
        case .below: "Below range"
        case .within: "Within range"
        case .above: "Above range"
        case .unknown: "No reading"
        }
    }

    /// Phrase used in headlines: "below your target range".
    var relationPhrase: String {
        switch self {
        case .below: "below your target range"
        case .within: "within your target range"
        case .above: "above your target range"
        case .unknown: "not recorded"
        }
    }

    var symbolName: String {
        switch self {
        case .below: "arrow.down.circle.fill"
        case .within: "checkmark.circle.fill"
        case .above: "arrow.up.circle.fill"
        case .unknown: "circle"
        }
    }

    /// Colour mapping for existing charts and gauges. Outside a saved target stays amber.
    var readingStatus: WaterChemistryReadingStatus {
        switch self {
        case .within, .unknown: .inRange
        case .below, .above: .caution
        }
    }

    var isOutsideTarget: Bool {
        self == .below || self == .above
    }
}

enum WaterChemistryReadingStatus {
    case inRange
    case caution
    case attention
}

enum WaterChemistryRanges {
    /// Starting values shown before someone saves their own targets.
    static let startingPH: ClosedRange<Double> = 7.2 ... 7.8
    static let startingChlorine: ClosedRange<Double> = 3.0 ... 5.0
    static let startingBromine: ClosedRange<Double> = 3.0 ... 5.0
    static let startingCombinedChlorine: ClosedRange<Double> = 0.0 ... 0.5

    static let phEntryBounds: ClosedRange<Double> = 0 ... 14
    static let ppmEntryBounds: ClosedRange<Double> = 0 ... 20

    static let phDisplay: ClosedRange<Double> = 6.8 ... 8.2
    static let chlorineDisplay: ClosedRange<Double> = 0 ... 6
    static let bromineDisplay: ClosedRange<Double> = 0 ... 6

    static func storedRange(
        minimum: Double,
        maximum: Double,
        fallback: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        guard minimum < maximum else { return fallback }
        return minimum ... maximum
    }

    static func displayRange(
        covering target: ClosedRange<Double>,
        fallback: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        let lower = min(target.lowerBound, fallback.lowerBound)
        let upper = max(target.upperBound, fallback.upperBound)
        guard lower < upper else { return fallback }
        return lower ... upper
    }

    static func readingStatus(value: Double, target: ClosedRange<Double>) -> WaterChemistryReadingStatus {
        RangeStatus(value: value, target: target).readingStatus
    }

    static func statusColor(_ status: WaterChemistryReadingStatus, palette: AppPalette) -> Color {
        switch status {
        case .inRange: palette.color(.accentGreen)
        case .caution: palette.color(.accentOrange)
        case .attention: palette.color(.accentRed)
        }
    }

    static func formatBound(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func targetLabel(_ range: ClosedRange<Double>, unit: String = "") -> String {
        let bounds = "\(formatBound(range.lowerBound))–\(formatBound(range.upperBound))"
        if unit.isEmpty { return bounds }
        return "\(bounds) \(unit)"
    }

    static func placeholder(_ range: ClosedRange<Double>) -> String {
        "\(formatBound(range.lowerBound))-\(formatBound(range.upperBound))"
    }

    static func parseDecimal(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}
