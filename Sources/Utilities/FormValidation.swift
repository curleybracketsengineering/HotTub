//
//  FormValidation.swift
//  HotTub
//

import Foundation

enum FormValidation {
    static let outOfRangeMessage = "Out of validation range"

    /// Inline blur validation for optional numeric range fields (empty is valid).
    static func blurRangeError(for text: String, min: Double, max: Double) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        guard let v = Double(t), !v.isNaN else { return "Must be a number" }
        if v < min || v > max { return outOfRangeMessage }
        return nil
    }

    /// Inline blur validation for optional non-negative numeric fields (empty is valid).
    static func blurNonNegativeError(for text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        guard let v = Double(t), !v.isNaN else { return "Must be a number" }
        if v < 0 { return outOfRangeMessage }
        return nil
    }

    static func isFutureDate(ymd: String) -> Bool {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: ymd) else { return false }
        let start = Calendar.current.startOfDay(for: d)
        let today = Calendar.current.startOfDay(for: Date())
        return start > today
    }

    /// True if the event’s calendar day is after today (local timezone).
    static func isFutureLoggedDay(_ moment: Date) -> Bool {
        let cal = Calendar.current
        let eventDay = cal.startOfDay(for: moment)
        let today = cal.startOfDay(for: Date())
        return eventDay > today
    }

    /// Upper bound for log date pickers: end of today in the local calendar.
    static func latestLoggableMoment() -> Date {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        return cal.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? Date()
    }

    static func validateDailyLog(
        loggedAt: Date,
        ph: String,
        sanitizerFree: String,
        sanitizerCombined: String,
        addedSanitizer: String,
        addedPhUp: String,
        addedPhDown: String,
        notes: String,
        isBromine: Bool
    ) -> [String] {
        let sanitizerName = isBromine ? "Bromine" : "Chlorine"
        var errors: [String] = []
        if isFutureLoggedDay(loggedAt) {
            errors.append("Cannot log data for a future date")
        }
        if let e = validateOptionalRange(ph, min: 0, max: 14, label: "pH") { errors.append(e) }
        let freeLabel = isBromine ? "Bromine (ppm)" : "Free chlorine (ppm)"
        if let e = validateOptionalRange(sanitizerFree, min: 0, max: 20, label: freeLabel) { errors.append(e) }
        if let e = validateOptionalRange(sanitizerCombined, min: 0, max: 20, label: "\(sanitizerName) combined") {
            errors.append(e)
        }
        if let e = validateOptionalNonNegative(addedSanitizer, label: "\(sanitizerName) added") { errors.append(e) }
        if let e = validateOptionalNonNegative(addedPhUp, label: "pH Up") { errors.append(e) }
        if let e = validateOptionalNonNegative(addedPhDown, label: "pH Down") { errors.append(e) }

        return errors
    }

    static func validateWeekly(
        loggedAt: Date,
        combined: String,
        total: String,
        alkalinity: String,
        copper: String,
        shock: String,
        alkUp: String,
        notes: String,
        waterClarity: String,
        foamPresent: Bool,
        isBromine: Bool
    ) -> [String] {
        let sanitizerName = isBromine ? "Bromine" : "Chlorine"
        var errors: [String] = []
        if isFutureLoggedDay(loggedAt) {
            errors.append("Cannot log data for a future date")
        }
        if let e = validateOptionalRange(combined, min: 0, max: 50, label: "Combined \(sanitizerName.lowercased()) (ppm)") { errors.append(e) }
        if let e = validateOptionalRange(total, min: 0, max: 50, label: "Total \(sanitizerName.lowercased()) (ppm)") { errors.append(e) }
        if let e = validateOptionalRange(alkalinity, min: 0, max: 300, label: "Total alkalinity") { errors.append(e) }
        if let e = validateOptionalRange(copper, min: 0, max: 5, label: "Copper") { errors.append(e) }
        if let e = validateOptionalNonNegative(shock, label: "Shock added") { errors.append(e) }
        if let e = validateOptionalNonNegative(alkUp, label: "Alkalinity Up") { errors.append(e) }

        let hasAny =
            !combined.trimmingCharacters(in: .whitespaces).isEmpty
            || !total.trimmingCharacters(in: .whitespaces).isEmpty
            || !alkalinity.trimmingCharacters(in: .whitespaces).isEmpty
            || !copper.trimmingCharacters(in: .whitespaces).isEmpty
            || !shock.trimmingCharacters(in: .whitespaces).isEmpty
            || !alkUp.trimmingCharacters(in: .whitespaces).isEmpty
            || !notes.trimmingCharacters(in: .whitespaces).isEmpty
            || !waterClarity.trimmingCharacters(in: .whitespaces).isEmpty
            || foamPresent

        if !hasAny {
            errors.append("Enter at least one weekly check value or notes")
        }
        return errors
    }

    static func validateMaintenance(
        loggedAt: Date,
        action: String,
        waterChange: Bool,
        filterChanged: Bool,
        filterRinsed: Bool
    ) -> [String] {
        var errors: [String] = []
        if isFutureLoggedDay(loggedAt) {
            errors.append("Cannot log service for a future date")
        }
        let trimmed = action.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty && !waterChange && !filterChanged && !filterRinsed {
            errors.append("Enter an action or enable a service option")
        }
        return errors
    }

    static func validateUsage(loggedAt: Date) -> [String] {
        if isFutureLoggedDay(loggedAt) {
            return ["Cannot log usage for a future date"]
        }
        return []
    }

    private static func validateOptionalRange(_ text: String, min: Double, max: Double, label: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        guard let v = Double(t), !v.isNaN else { return "\(label) must be a number" }
        if v < min || v > max { return "\(label) must be between \(min) and \(max)" }
        return nil
    }

    private static func validateOptionalNonNegative(_ text: String, label: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        guard let v = Double(t), !v.isNaN else { return "\(label) must be a number" }
        if v < 0 { return "\(label) cannot be negative" }
        return nil
    }
}

enum LogFormFormatting {
    static func todayYMD() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func nowHM() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    static func nowHMS() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
