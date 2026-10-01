//
//  TargetRangeDraft.swift
//  HotTub
//

import Foundation

/// Editable copy of the comparison targets, validated before it is saved.
struct TargetRangeDraft: Equatable {
    var sanitizerType: String = "chlorine"
    var phMinimum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingPH.lowerBound)
    var phMaximum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingPH.upperBound)
    var chlorineMinimum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingChlorine.lowerBound)
    var chlorineMaximum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingChlorine.upperBound)
    var bromineMinimum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingBromine.lowerBound)
    var bromineMaximum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingBromine.upperBound)
    var combinedChlorineMinimum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingCombinedChlorine.lowerBound)
    var combinedChlorineMaximum: String = WaterChemistryRanges.formatBound(WaterChemistryRanges.startingCombinedChlorine.upperBound)

    var isBromine: Bool {
        sanitizerType.lowercased() == "bromine"
    }

    init() {}

    init(settings: AppSettings) {
        sanitizerType = settings.sanitizerType
        phMinimum = WaterChemistryRanges.formatBound(settings.phTargetMinimum)
        phMaximum = WaterChemistryRanges.formatBound(settings.phTargetMaximum)
        chlorineMinimum = WaterChemistryRanges.formatBound(settings.chlorineTargetMinimum)
        chlorineMaximum = WaterChemistryRanges.formatBound(settings.chlorineTargetMaximum)
        bromineMinimum = WaterChemistryRanges.formatBound(settings.bromineTargetMinimum)
        bromineMaximum = WaterChemistryRanges.formatBound(settings.bromineTargetMaximum)
        combinedChlorineMinimum = WaterChemistryRanges.formatBound(settings.combinedChlorineTargetMinimum)
        combinedChlorineMaximum = WaterChemistryRanges.formatBound(settings.combinedChlorineTargetMaximum)
    }

    var validationMessage: String? {
        if let message = validatePair(
            name: "pH",
            minimum: phMinimum,
            maximum: phMaximum,
            bounds: WaterChemistryRanges.phEntryBounds
        ) {
            return message
        }
        if isBromine {
            return validatePair(
                name: "Bromine",
                minimum: bromineMinimum,
                maximum: bromineMaximum,
                bounds: WaterChemistryRanges.ppmEntryBounds
            )
        }
        if let message = validatePair(
            name: "Free chlorine",
            minimum: chlorineMinimum,
            maximum: chlorineMaximum,
            bounds: WaterChemistryRanges.ppmEntryBounds
        ) {
            return message
        }
        return validatePair(
            name: "Combined chlorine",
            minimum: combinedChlorineMinimum,
            maximum: combinedChlorineMaximum,
            bounds: WaterChemistryRanges.ppmEntryBounds
        )
    }

    func apply(to settings: AppSettings, includeSanitizerType: Bool) {
        guard validationMessage == nil else { return }
        if includeSanitizerType {
            settings.sanitizerType = isBromine ? "bromine" : "chlorine"
        }
        if let minimum = WaterChemistryRanges.parseDecimal(phMinimum),
           let maximum = WaterChemistryRanges.parseDecimal(phMaximum) {
            settings.phTargetMinimum = minimum
            settings.phTargetMaximum = maximum
        }
        if isBromine {
            if let minimum = WaterChemistryRanges.parseDecimal(bromineMinimum),
               let maximum = WaterChemistryRanges.parseDecimal(bromineMaximum) {
                settings.bromineTargetMinimum = minimum
                settings.bromineTargetMaximum = maximum
            }
        } else {
            if let minimum = WaterChemistryRanges.parseDecimal(chlorineMinimum),
               let maximum = WaterChemistryRanges.parseDecimal(chlorineMaximum) {
                settings.chlorineTargetMinimum = minimum
                settings.chlorineTargetMaximum = maximum
            }
            if let minimum = WaterChemistryRanges.parseDecimal(combinedChlorineMinimum),
               let maximum = WaterChemistryRanges.parseDecimal(combinedChlorineMaximum) {
                settings.combinedChlorineTargetMinimum = minimum
                settings.combinedChlorineTargetMaximum = maximum
            }
        }
    }

    private func validatePair(
        name: String,
        minimum: String,
        maximum: String,
        bounds: ClosedRange<Double>
    ) -> String? {
        guard let lower = WaterChemistryRanges.parseDecimal(minimum),
              let upper = WaterChemistryRanges.parseDecimal(maximum) else {
            return "Enter a minimum and maximum for \(name)."
        }
        let lowerLabel = WaterChemistryRanges.formatBound(bounds.lowerBound)
        let upperLabel = WaterChemistryRanges.formatBound(bounds.upperBound)
        if !bounds.contains(lower) || !bounds.contains(upper) {
            return "\(name) must be between \(lowerLabel) and \(upperLabel)."
        }
        if lower >= upper {
            return "\(name) minimum must be below the maximum."
        }
        return nil
    }
}
