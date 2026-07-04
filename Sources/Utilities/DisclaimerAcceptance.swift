//
//  DisclaimerAcceptance.swift
//  HotTub
//

import Foundation

enum DisclaimerAcceptance {
    static let currentVersion = "1.0"
    static let lastUpdated = "February 20, 2026"
    static let storageKey = "disclaimerAcceptedVersion"

    static func isAccepted(_ storedVersion: String) -> Bool {
        storedVersion == currentVersion
    }
}
