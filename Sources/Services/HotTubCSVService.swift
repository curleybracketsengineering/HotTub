//
//  HotTubCSVService.swift
//  HotTub
//
//  Export and import user logs as a simple CSV file.
//

import Foundation
import SwiftData

struct HotTubCSVImportResult {
    var settingsUpdated = false
    var dailyAdded = 0
    var weeklyAdded = 0
    var maintenanceAdded = 0
    var usageAdded = 0
    var skippedDuplicates = 0
    var skippedInvalid = 0
    var errors: [String] = []

    var summary: String {
        var parts: [String] = []
        if settingsUpdated { parts.append("Settings updated") }
        let added = dailyAdded + weeklyAdded + maintenanceAdded + usageAdded
        if added > 0 {
            var detail: [String] = []
            if dailyAdded > 0 { detail.append("\(dailyAdded) daily") }
            if weeklyAdded > 0 { detail.append("\(weeklyAdded) weekly") }
            if maintenanceAdded > 0 { detail.append("\(maintenanceAdded) service") }
            if usageAdded > 0 { detail.append("\(usageAdded) usage") }
            parts.append("Added \(detail.joined(separator: ", "))")
        }
        if skippedDuplicates > 0 {
            parts.append("Skipped \(skippedDuplicates) duplicate\(skippedDuplicates == 1 ? "" : "s")")
        }
        if skippedInvalid > 0 {
            parts.append("Skipped \(skippedInvalid) invalid row\(skippedInvalid == 1 ? "" : "s")")
        }
        if parts.isEmpty { return "No new records were imported." }
        return parts.joined(separator: ". ") + "."
    }
}

enum HotTubCSVError: LocalizedError {
    case emptyFile
    case missingHeader
    case unreadable

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "The file is empty."
        case .missingHeader: return "The file must include a header row with column names."
        case .unreadable: return "Could not read the selected file."
        }
    }
}

enum HotTubCSVService {
    private static let columns = [
        "type",
        "logged_at",
        "water_temperature",
        "ph",
        "sanitizer_free",
        "sanitizer_combined",
        "added_sanitizer",
        "added_ph_up",
        "added_ph_down",
        "notes",
        "combined_chlorine",
        "sanitizer_total",
        "total_alkalinity",
        "copper",
        "shock_added",
        "shock_type",
        "alkalinity_up_added",
        "water_clarity",
        "foam_present",
        "action",
        "filter_changed",
        "water_change",
        "num_users",
        "duration_minutes",
        "capacity",
        "capacity_unit",
        "measurement_system",
        "sanitizer_type",
    ]

    private static let columnAliases: [String: String] = [
        "record_type": "type",
        "log_type": "type",
        "date": "logged_at",
        "datetime": "logged_at",
        "timestamp": "logged_at",
        "time": "logged_time",
        "temp": "water_temperature",
        "temperature": "water_temperature",
        "water_temp": "water_temperature",
        "free_chlorine": "sanitizer_free",
        "fc": "sanitizer_free",
        "bromine": "sanitizer_free",
        "free_bromine": "sanitizer_free",
        "combined_chlorine_ppm": "sanitizer_combined",
        "cc": "sanitizer_combined",
        "combined": "sanitizer_combined",
        "chlorine_added": "added_sanitizer",
        "bromine_added": "added_sanitizer",
        "ph_up": "added_ph_up",
        "ph_down": "added_ph_down",
        "ta": "total_alkalinity",
        "alkalinity": "total_alkalinity",
        "total_alk": "total_alkalinity",
        "shock": "shock_added",
        "alk_up": "alkalinity_up_added",
        "alkalinity_up": "alkalinity_up_added",
        "clarity": "water_clarity",
        "foam": "foam_present",
        "people": "num_users",
        "users": "num_users",
        "duration": "duration_minutes",
        "minutes": "duration_minutes",
        "unit": "capacity_unit",
        "measurements": "measurement_system",
        "sanitizer": "sanitizer_type",
    ]

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    // MARK: - Export

    @MainActor
    static func exportCSV(in context: ModelContext) throws -> String {
        let settings = try fetchSettings(in: context)
        let daily = try context.fetch(FetchDescriptor<HotTubDailyLog>(sortBy: [SortDescriptor(\.loggedAt)]))
        let weekly = try context.fetch(FetchDescriptor<WeeklyCheckLog>(sortBy: [SortDescriptor(\.loggedAt)]))
        let maintenance = try context.fetch(FetchDescriptor<MaintenanceLogEntry>(sortBy: [SortDescriptor(\.loggedAt)]))
        let usage = try context.fetch(FetchDescriptor<UsageLogEntry>(sortBy: [SortDescriptor(\.loggedAt)]))

        var rows: [[String: String]] = []
        if let settings {
            rows.append(settingsRow(settings))
        }

        rows.append(contentsOf: daily.map(dailyRow))
        rows.append(contentsOf: weekly.map(weeklyRow))
        rows.append(contentsOf: maintenance.map(maintenanceRow))
        rows.append(contentsOf: usage.map(usageRow))

        return serialize(rows: rows)
    }

    static func suggestedExportFilename() -> String {
        "\(suggestedExportBaseFilename()).csv"
    }

    static func suggestedExportBaseFilename() -> String {
        let stamp = exportDateFormatter.string(from: .now).prefix(10)
        return "HotTub-Buddy-\(stamp)"
    }

    /// Strips `.csv`, whitespace, and characters that are invalid in file names.
    static func sanitizedExportBaseName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased().hasSuffix(".csv") {
            name = String(name.dropLast(4))
        }
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        name = name.components(separatedBy: invalid).joined(separator: "-")
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Import

    @MainActor
    static func importCSV(_ text: String, in context: ModelContext) throws -> HotTubCSVImportResult {
        let parsed = try parse(text)
        guard let header = parsed.first else { throw HotTubCSVError.missingHeader }

        var columnIndex: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            let normalized = normalizeColumn(name)
            if !normalized.isEmpty {
                columnIndex[normalized] = index
            }
        }

        guard !columnIndex.isEmpty else { throw HotTubCSVError.missingHeader }

        let defaultType = inferDefaultType(from: columnIndex)
        var result = HotTubCSVImportResult()
        var existingKeys = try existingDuplicateKeys(in: context)

        for row in parsed.dropFirst() {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                continue
            }

            let fields = fieldMap(from: row, columnIndex: columnIndex)
            let type = resolveRowType(fields: fields, columnIndex: columnIndex, defaultType: defaultType)

            if type == "settings" {
                if applySettings(from: fields, in: context) {
                    result.settingsUpdated = true
                } else {
                    result.skippedInvalid += 1
                }
                continue
            }

            guard let loggedAt = parseLoggedAt(from: fields) else {
                result.skippedInvalid += 1
                continue
            }

            let key = DuplicateKey(type: type, loggedAt: loggedAt)
            if existingKeys.contains(key) {
                result.skippedDuplicates += 1
                continue
            }

            switch type {
            case "daily":
                guard insertDaily(from: fields, loggedAt: loggedAt, in: context) else {
                    result.skippedInvalid += 1
                    continue
                }
                result.dailyAdded += 1
            case "weekly":
                guard insertWeekly(from: fields, loggedAt: loggedAt, in: context) else {
                    result.skippedInvalid += 1
                    continue
                }
                result.weeklyAdded += 1
            case "maintenance":
                guard insertMaintenance(from: fields, loggedAt: loggedAt, in: context) else {
                    result.skippedInvalid += 1
                    continue
                }
                result.maintenanceAdded += 1
            case "usage":
                guard insertUsage(from: fields, loggedAt: loggedAt, in: context) else {
                    result.skippedInvalid += 1
                    continue
                }
                result.usageAdded += 1
            default:
                result.skippedInvalid += 1
                continue
            }

            existingKeys.insert(key)
        }

        if result.dailyAdded + result.weeklyAdded + result.maintenanceAdded + result.usageAdded > 0 || result.settingsUpdated {
            try context.save()
        }

        return result
    }

    // MARK: - Row builders

    private static func settingsRow(_ settings: AppSettings) -> [String: String] {
        [
            "type": "settings",
            "capacity": formatNumber(settings.capacity),
            "capacity_unit": settings.capacityUnit,
            "measurement_system": settings.measurementSystem,
            "sanitizer_type": settings.sanitizerType,
        ]
    }

    private static func dailyRow(_ log: HotTubDailyLog) -> [String: String] {
        var row: [String: String] = [
            "type": "daily",
            "logged_at": exportDateFormatter.string(from: log.loggedAt),
            "added_sanitizer": formatNumber(log.addedSanitizer),
            "added_ph_up": formatNumber(log.addedPhUp),
            "added_ph_down": formatNumber(log.addedPhDown),
        ]
        if let value = log.waterTemperature { row["water_temperature"] = String(value) }
        if let value = log.ph { row["ph"] = formatNumber(value) }
        if let value = log.sanitizerFree { row["sanitizer_free"] = formatNumber(value) }
        if let value = log.sanitizerCombined { row["sanitizer_combined"] = formatNumber(value) }
        if let notes = log.notes, !notes.isEmpty { row["notes"] = notes }
        return row
    }

    private static func weeklyRow(_ log: WeeklyCheckLog) -> [String: String] {
        var row: [String: String] = [
            "type": "weekly",
            "logged_at": exportDateFormatter.string(from: log.loggedAt),
            "shock_type": log.shockType,
            "water_clarity": log.waterClarity,
            "foam_present": log.foamPresent ? "true" : "false",
        ]
        if let value = log.combinedChlorine { row["combined_chlorine"] = formatNumber(value) }
        if let value = log.sanitizerTotal { row["sanitizer_total"] = formatNumber(value) }
        if let value = log.totalAlkalinity { row["total_alkalinity"] = formatNumber(value) }
        if let value = log.copper { row["copper"] = formatNumber(value) }
        if let value = log.shockAdded { row["shock_added"] = formatNumber(value) }
        if let value = log.alkalinityUpAdded { row["alkalinity_up_added"] = formatNumber(value) }
        if let notes = log.notes, !notes.isEmpty { row["notes"] = notes }
        return row
    }

    private static func maintenanceRow(_ log: MaintenanceLogEntry) -> [String: String] {
        var row: [String: String] = [
            "type": "maintenance",
            "logged_at": exportDateFormatter.string(from: log.loggedAt),
            "action": log.action,
            "filter_rinsed": log.filterRinsed ? "true" : "false",
            "filter_changed": log.filterChanged ? "true" : "false",
            "water_change": log.waterChange ? "true" : "false",
        ]
        if !log.notes.isEmpty { row["notes"] = log.notes }
        return row
    }

    private static func usageRow(_ log: UsageLogEntry) -> [String: String] {
        var row: [String: String] = [
            "type": "usage",
            "logged_at": exportDateFormatter.string(from: log.loggedAt),
            "num_users": String(log.numUsers),
            "duration_minutes": String(log.durationMinutes),
        ]
        if let value = log.waterTemperature { row["water_temperature"] = String(value) }
        return row
    }

    // MARK: - Insert helpers

    @MainActor
    private static func insertDaily(from fields: [String: String], loggedAt: Date, in context: ModelContext) -> Bool {
        let log = HotTubDailyLog(
            loggedAt: loggedAt,
            waterTemperature: parseInt(fields["water_temperature"]),
            ph: parseOptionalDouble(fields["ph"]),
            sanitizerFree: parseOptionalDouble(fields["sanitizer_free"]),
            sanitizerCombined: parseOptionalDouble(fields["sanitizer_combined"]),
            addedPhUp: parseNonNegativeDouble(fields["added_ph_up"]),
            addedPhDown: parseNonNegativeDouble(fields["added_ph_down"]),
            addedSanitizer: parseNonNegativeDouble(fields["added_sanitizer"]),
            notes: emptyToNil(fields["notes"])
        )
        context.insert(log)
        return true
    }

    @MainActor
    private static func insertWeekly(from fields: [String: String], loggedAt: Date, in context: ModelContext) -> Bool {
        let log = WeeklyCheckLog(
            loggedAt: loggedAt,
            combinedChlorine: parseOptionalDouble(fields["combined_chlorine"]),
            sanitizerTotal: parseOptionalDouble(fields["sanitizer_total"]),
            totalAlkalinity: parseOptionalDouble(fields["total_alkalinity"]),
            copper: parseOptionalDouble(fields["copper"]),
            shockAdded: parseOptionalDouble(fields["shock_added"]),
            shockType: fields["shock_type"]?.trimmingCharacters(in: .whitespaces) ?? "",
            alkalinityUpAdded: parseOptionalDouble(fields["alkalinity_up_added"]),
            notes: emptyToNil(fields["notes"]),
            waterClarity: fields["water_clarity"]?.trimmingCharacters(in: .whitespaces) ?? "",
            foamPresent: parseBool(fields["foam_present"]) ?? false
        )
        context.insert(log)
        return true
    }

    @MainActor
    private static func insertMaintenance(from fields: [String: String], loggedAt: Date, in context: ModelContext) -> Bool {
        let log = MaintenanceLogEntry(
            loggedAt: loggedAt,
            action: fields["action"]?.trimmingCharacters(in: .whitespaces) ?? "",
            notes: fields["notes"]?.trimmingCharacters(in: .whitespaces) ?? "",
            filterRinsed: parseBool(fields["filter_rinsed"]) ?? false,
            filterChanged: parseBool(fields["filter_changed"]) ?? false,
            waterChange: parseBool(fields["water_change"]) ?? false
        )
        context.insert(log)
        return true
    }

    @MainActor
    private static func insertUsage(from fields: [String: String], loggedAt: Date, in context: ModelContext) -> Bool {
        let numUsers = max(1, parseInt(fields["num_users"]) ?? 1)
        let duration = max(1, parseInt(fields["duration_minutes"]) ?? 15)

        let log = UsageLogEntry(
            loggedAt: loggedAt,
            numUsers: numUsers,
            durationMinutes: duration,
            waterTemperature: parseInt(fields["water_temperature"])
        )
        context.insert(log)
        return true
    }

    @MainActor
    private static func applySettings(from fields: [String: String], in context: ModelContext) -> Bool {
        guard let settings = try? fetchSettings(in: context) else { return false }

        if let capacity = parseOptionalDouble(fields["capacity"]) {
            settings.capacity = max(0, capacity)
        }
        if let unit = fields["capacity_unit"]?.trimmingCharacters(in: .whitespaces), !unit.isEmpty {
            settings.capacityUnit = unit
        }
        if let system = fields["measurement_system"]?.trimmingCharacters(in: .whitespaces), !system.isEmpty {
            settings.measurementSystem = system
            settings.temperatureUnit = system == "metric" ? "celsius" : "fahrenheit"
        }
        if let sanitizer = fields["sanitizer_type"]?.trimmingCharacters(in: .whitespaces), !sanitizer.isEmpty {
            settings.sanitizerType = sanitizer
        }
        settings.updatedAt = .now
        return true
    }

    // MARK: - Duplicate detection

    private struct DuplicateKey: Hashable {
        let type: String
        let minute: Date

        init(type: String, loggedAt: Date) {
            self.type = type
            self.minute = Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: loggedAt)
            ) ?? loggedAt
        }
    }

    @MainActor
    private static func existingDuplicateKeys(in context: ModelContext) throws -> Set<DuplicateKey> {
        var keys = Set<DuplicateKey>()
        let daily = try context.fetch(FetchDescriptor<HotTubDailyLog>())
        daily.forEach { keys.insert(DuplicateKey(type: "daily", loggedAt: $0.loggedAt)) }
        let weekly = try context.fetch(FetchDescriptor<WeeklyCheckLog>())
        weekly.forEach { keys.insert(DuplicateKey(type: "weekly", loggedAt: $0.loggedAt)) }
        let maintenance = try context.fetch(FetchDescriptor<MaintenanceLogEntry>())
        maintenance.forEach { keys.insert(DuplicateKey(type: "maintenance", loggedAt: $0.loggedAt)) }
        let usage = try context.fetch(FetchDescriptor<UsageLogEntry>())
        usage.forEach { keys.insert(DuplicateKey(type: "usage", loggedAt: $0.loggedAt)) }
        return keys
    }

    // MARK: - CSV parsing

    private static func parse(_ text: String) throws -> [[String]] {
        var content = text
        if content.hasPrefix("\u{FEFF}") {
            content.removeFirst()
        }
        content = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw HotTubCSVError.emptyFile }

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = trimmed.startIndex

        while index < trimmed.endIndex {
            let char = trimmed[index]

            if inQuotes {
                if char == "\"" {
                    let next = trimmed.index(after: index)
                    if next < trimmed.endIndex, trimmed[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == "," {
                row.append(field)
                field = ""
            } else if char == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(char)
            }

            index = trimmed.index(after: index)
        }

        row.append(field)
        if !(row.count == 1 && row[0].isEmpty) {
            rows.append(row)
        }

        return rows
    }

    private static func serialize(rows: [[String: String]]) -> String {
        var lines: [String] = [columns.joined(separator: ",")]
        for row in rows {
            let values = columns.map { column in
                escape(row[column] ?? "")
            }
            lines.append(values.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func fieldMap(from row: [String], columnIndex: [String: Int]) -> [String: String] {
        var fields: [String: String] = [:]
        for (column, index) in columnIndex where index < row.count {
            let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                fields[column] = value
            }
        }
        return fields
    }

    private static func normalizeColumn(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        if lowered.isEmpty { return "" }
        return columnAliases[lowered] ?? lowered
    }

    private static func normalizedType(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "daily", "day", "d": return "daily"
        case "weekly", "week", "w": return "weekly"
        case "maintenance", "maint", "m": return "maintenance"
        case "usage", "session", "u": return "usage"
        case "settings", "setting", "config": return "settings"
        default: return value.isEmpty ? nil : value
        }
    }

    private static func inferDefaultType(from columnIndex: [String: Int]) -> String {
        if columnIndex["type"] != nil { return "daily" }
        if columnIndex["action"] != nil || columnIndex["filter_changed"] != nil { return "maintenance" }
        if columnIndex["total_alkalinity"] != nil || columnIndex["water_clarity"] != nil { return "weekly" }
        if columnIndex["ph"] != nil || columnIndex["sanitizer_free"] != nil || columnIndex["sanitizer_combined"] != nil {
            return "daily"
        }
        if columnIndex["num_users"] != nil || columnIndex["duration_minutes"] != nil { return "usage" }
        return "daily"
    }

    /// Per-row type when the `type` column is missing or empty.
    /// Prefers water-test rows over usage when chemistry fields are populated — avoids
    /// mis-importing spreadsheets that reuse the full export header with ppm in wrong columns.
    private static func resolveRowType(
        fields: [String: String],
        columnIndex: [String: Int],
        defaultType: String
    ) -> String {
        if let explicit = normalizedType(fields["type"]) { return explicit }

        let hasDaily = fields["ph"] != nil
            || fields["sanitizer_free"] != nil
            || fields["sanitizer_combined"] != nil
            || fields["added_sanitizer"] != nil
            || fields["added_ph_up"] != nil
            || fields["added_ph_down"] != nil
        let hasWeekly = fields["total_alkalinity"] != nil
            || fields["water_clarity"] != nil
            || fields["combined_chlorine"] != nil
            || fields["sanitizer_total"] != nil
        let hasMaintenance = fields["action"] != nil
            || fields["filter_changed"] != nil
            || fields["water_change"] != nil
            || fields["filter_rinsed"] != nil
        let hasUsage = fields["num_users"] != nil || fields["duration_minutes"] != nil

        if hasDaily && !hasUsage { return "daily" }
        if hasWeekly && !hasUsage { return "weekly" }
        if hasMaintenance && !hasDaily && !hasWeekly && !hasUsage { return "maintenance" }
        if hasUsage && !hasDaily && !hasWeekly { return "usage" }
        if hasDaily { return "daily" }
        if hasWeekly { return "weekly" }
        if hasMaintenance { return "maintenance" }
        if hasUsage { return "usage" }
        return defaultType
    }

    private static func parseLoggedAt(from fields: [String: String]) -> Date? {
        if let combined = fields["logged_at"], let date = parseDate(combined) {
            return date
        }

        if let datePart = fields["logged_at"] ?? fields["date"], let timePart = fields["logged_time"] ?? fields["time"] {
            return parseDate("\(datePart) \(timePart)") ?? parseDate("\(datePart)T\(timePart)")
        }

        if let datePart = fields["date"] {
            return parseDate(datePart)
        }

        return nil
    }

    private static func parseDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        if let date = ISO8601DateFormatter().date(from: trimmed) { return date }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "d/M/yyyy HH:mm",
            "d/M/yyyy",
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    // MARK: - Value parsing

    private static func parseOptionalDouble(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        return FormFieldParsing.optionalDouble(from: raw)
    }

    private static func parseNonNegativeDouble(_ raw: String?) -> Double {
        guard let raw else { return 0 }
        return FormFieldParsing.nonNegativeDouble(from: raw)
    }

    private static func parseInt(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if let value = Int(trimmed) { return value }
        if let value = Double(trimmed) { return Int(value.rounded()) }
        return nil
    }

    private static func parseBool(_ raw: String?) -> Bool? {
        guard let raw else { return nil }
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "yes", "y", "1": return true
        case "false", "no", "n", "0": return false
        default: return nil
        }
    }

    private static func emptyToNil(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func formatNumber(_ value: Double) -> String {
        String(format: "%g", value)
    }

    @MainActor
    private static func fetchSettings(in context: ModelContext) throws -> AppSettings? {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
