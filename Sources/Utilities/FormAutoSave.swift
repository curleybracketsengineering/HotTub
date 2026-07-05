//
//  FormAutoSave.swift
//  HotTub
//

import Foundation

enum FormFieldParsing {
    static func optionalDouble(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let value = Double(trimmed), !value.isNaN else { return nil }
        return value
    }

    static func nonNegativeDouble(from text: String, default defaultValue: Double = 0) -> Double {
        optionalDouble(from: text).map { max(0, $0) } ?? defaultValue
    }

    /// Parses a number only when it lies within `min...max` (empty text → nil).
    static func validatedOptionalDouble(from text: String, min: Double, max: Double) -> Double? {
        guard let value = optionalDouble(from: text) else { return nil }
        guard value >= min, value <= max else { return nil }
        return value
    }
}
