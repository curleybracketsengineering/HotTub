//
//  ShockTypes.swift
//  HotTub
//

import Foundation

enum ShockTypes {
    /// Shock types that add sanitizer (exclude periods from consumption calc).
    static let sanitizerAdding: Set<String> = [
        "cal-hypo",
        "dichlor",
        "lithium-hypo",
        "bromine-granules",
    ]

    static func isSanitizerAddingShock(_ shockType: String?) -> Bool {
        guard let shockType, !shockType.isEmpty else { return false }
        return sanitizerAdding.contains(shockType)
    }
}
