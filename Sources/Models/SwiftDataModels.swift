//
//  SwiftDataModels.swift
//  HotTub
//
//  SwiftData persistence aligned with the React app’s AsyncStorage shapes
//  (daily logs, weekly checks, maintenance, usage, settings).
//
//  CloudKit requires inline property defaults (init defaults are not enough)
//  and does not support @Attribute(.unique).
//

import Foundation
import SwiftData

// MARK: - App settings (single logical row; bootstrap ensures one instance)

@Model
final class AppSettings {
    /// Stable key for singleton consolidation across devices (not a CloudKit unique constraint).
    var settingsKey: String = "default"
    var capacity: Double = 1000
    var capacityUnit: String = "liters"
    var measurementSystem: String = "metric"
    var sanitizerType: String = "chlorine"
    var temperatureUnit: String = "celsius"
    var updatedAt: Date = Date.now

    init(
        settingsKey: String = "default",
        capacity: Double = 1000,
        capacityUnit: String = "liters",
        measurementSystem: String = "metric",
        sanitizerType: String = "chlorine",
        temperatureUnit: String = "celsius",
        updatedAt: Date = .now
    ) {
        self.settingsKey = settingsKey
        self.capacity = capacity
        self.capacityUnit = capacityUnit
        self.measurementSystem = measurementSystem
        self.sanitizerType = sanitizerType
        self.temperatureUnit = temperatureUnit
        self.updatedAt = updatedAt
    }

    /// Volume in litres for calculators (matches React `volume_litres` fallback chain).
    var volumeLitres: Double {
        if capacityUnit.lowercased() == "liters" || capacityUnit.lowercased() == "litres" {
            return capacity
        }
        // imperial gallons → litres
        if capacityUnit.lowercased().contains("gallon") {
            return capacity * 3.78541
        }
        return capacity
    }

    var isBromine: Bool {
        sanitizerType.lowercased() == "bromine"
    }

    /// User-facing name for the selected sanitizer (Chlorine / Bromine).
    var sanitizerDisplayName: String {
        isBromine ? "Bromine" : "Chlorine"
    }
}

// MARK: - Daily hot tub log

@Model
final class HotTubDailyLog {
    /// When the reading was taken (date and time).
    var loggedAt: Date = Date.now
    var createdAt: Date = Date.now

    var waterTemperature: Int?

    var ph: Double?
    var sanitizerFree: Double?
    var sanitizerCombined: Double?

    var addedPhUp: Double = 0
    var addedPhDown: Double = 0
    var addedSanitizer: Double = 0

    var notes: String?

    init(
        loggedAt: Date,
        createdAt: Date = .now,
        waterTemperature: Int? = nil,
        ph: Double? = nil,
        sanitizerFree: Double? = nil,
        sanitizerCombined: Double? = nil,
        addedPhUp: Double = 0,
        addedPhDown: Double = 0,
        addedSanitizer: Double = 0,
        notes: String? = nil
    ) {
        self.loggedAt = loggedAt
        self.createdAt = createdAt
        self.waterTemperature = waterTemperature
        self.ph = ph
        self.sanitizerFree = sanitizerFree
        self.sanitizerCombined = sanitizerCombined
        self.addedPhUp = addedPhUp
        self.addedPhDown = addedPhDown
        self.addedSanitizer = addedSanitizer
        self.notes = notes
    }

    /// Primary ppm reading for charts and consumption math (free sanitizer / bromine).
    var primarySanitizerPpm: Double? {
        sanitizerFree
    }
}

// MARK: - Weekly check

@Model
final class WeeklyCheckLog {
    var loggedAt: Date = Date.now
    var createdAt: Date = Date.now

    var combinedChlorine: Double?
    /// Total sanitizer reading (ppm), e.g. total chlorine or total bromine on weekly check.
    var sanitizerTotal: Double?
    var totalAlkalinity: Double?
    var copper: Double?
    var shockAdded: Double?
    var shockType: String = ""
    var alkalinityUpAdded: Double?
    var notes: String?

    /// Free-text water clarity (e.g. clear, hazy).
    var waterClarity: String = ""
    /// Whether foam was present on inspection.
    var foamPresent: Bool = false

    init(
        loggedAt: Date,
        createdAt: Date = .now,
        combinedChlorine: Double? = nil,
        sanitizerTotal: Double? = nil,
        totalAlkalinity: Double? = nil,
        copper: Double? = nil,
        shockAdded: Double? = nil,
        shockType: String = "",
        alkalinityUpAdded: Double? = nil,
        notes: String? = nil,
        waterClarity: String = "",
        foamPresent: Bool = false
    ) {
        self.loggedAt = loggedAt
        self.createdAt = createdAt
        self.combinedChlorine = combinedChlorine
        self.sanitizerTotal = sanitizerTotal
        self.totalAlkalinity = totalAlkalinity
        self.copper = copper
        self.shockAdded = shockAdded
        self.shockType = shockType
        self.alkalinityUpAdded = alkalinityUpAdded
        self.notes = notes
        self.waterClarity = waterClarity
        self.foamPresent = foamPresent
    }
}

// MARK: - Maintenance

@Model
final class MaintenanceLogEntry {
    var loggedAt: Date = Date.now
    var createdAt: Date = Date.now

    var action: String = ""
    var notes: String = ""
    var filterChanged: Bool = false
    var waterChange: Bool = false

    init(
        loggedAt: Date,
        createdAt: Date = .now,
        action: String = "",
        notes: String = "",
        filterChanged: Bool = false,
        waterChange: Bool = false
    ) {
        self.loggedAt = loggedAt
        self.createdAt = createdAt
        self.action = action
        self.notes = notes
        self.filterChanged = filterChanged
        self.waterChange = waterChange
    }
}

// MARK: - Usage

@Model
final class UsageLogEntry {
    var loggedAt: Date = Date.now
    var createdAt: Date = Date.now

    var numUsers: Int = 1
    var durationMinutes: Int = 15
    var waterTemperature: Int?

    init(
        loggedAt: Date,
        createdAt: Date = .now,
        numUsers: Int = 1,
        durationMinutes: Int = 15,
        waterTemperature: Int? = nil
    ) {
        self.loggedAt = loggedAt
        self.createdAt = createdAt
        self.numUsers = numUsers
        self.durationMinutes = durationMinutes
        self.waterTemperature = waterTemperature
    }
}
