//
//  HelpTopic.swift
//  HotTub
//

import Foundation

/// Which pH section to expand when opening the shared pH help sheet.
enum PhHelpFocus: String, Hashable {
    case overview
    case down
    case up
}

/// Which sanitizer section to expand in the shared sanitizer help sheet.
enum SanitizerHelpFocus: String, Hashable {
    case overview
    case free
    case combined
    case total
}

/// Topic plus optional context (e.g. pH field vs pH Down added).
struct HelpSheetRequest: Identifiable, Hashable {
    var topic: HelpTopic
    var phFocus: PhHelpFocus
    var sanitizerFocus: SanitizerHelpFocus

    var id: String {
        switch topic {
        case .ph: return "ph-\(phFocus.rawValue)"
        case .sanitizer: return "sanitizer-\(sanitizerFocus.rawValue)"
        default: return topic.rawValue
        }
    }

    init(
        topic: HelpTopic,
        phFocus: PhHelpFocus = .overview,
        sanitizerFocus: SanitizerHelpFocus = .overview
    ) {
        self.topic = topic
        self.phFocus = phFocus
        self.sanitizerFocus = sanitizerFocus
    }

    static func ph(_ focus: PhHelpFocus = .overview) -> HelpSheetRequest {
        HelpSheetRequest(topic: .ph, phFocus: focus)
    }

    static func sanitizer(_ focus: SanitizerHelpFocus = .overview) -> HelpSheetRequest {
        HelpSheetRequest(topic: .sanitizer, sanitizerFocus: focus)
    }
}

/// Topics aligned with React `HelpModal` (`HelpModal.jsx`).
enum HelpTopic: String, CaseIterable, Identifiable, Hashable {
    case ph
    case sanitizer
    case copper
    case alkalinity
    case temperature
    case chemicalsAdded
    case shock
    case consumption
    case general

    var id: String { rawValue }

    /// Navigation / sheet title (matches React `getTitle` where applicable).
    var screenTitle: String {
        switch self {
        case .ph: return "pH Guide"
        case .sanitizer: return "Sanitizer Guide"
        case .copper: return "Copper (Cu) Guide"
        case .alkalinity: return "Total Alkalinity Guide"
        case .temperature: return "Temperature Guide"
        case .chemicalsAdded: return "Chemicals Added Guide"
        case .shock: return "Shock Treatment Guide"
        case .consumption: return "Sanitizer Consumption Guide"
        case .general: return "Help & Guide"
        }
    }
}
