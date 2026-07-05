//
//  UsageLogDiagnostics.swift
//  HotTub
//

import Foundation

enum UsageLogDiagnostics {
    /// Usage entries whose `numUsers` exactly matches the same-day water-test sanitizer ppm.
    /// Often indicates a bad CSV import or mistaken log — not real hot-tub sessions.
    static func entriesMatchingSanitizerPPM(
        usage: [UsageLogEntry],
        daily: [HotTubDailyLog],
        calendar: Calendar = .current
    ) -> [UsageLogEntry] {
        usage.filter { entry in
            matchesSanitizerPPM(entry, daily: daily, calendar: calendar)
        }
    }

    static func matchesSanitizerPPM(
        _ entry: UsageLogEntry,
        daily: [HotTubDailyLog],
        calendar: Calendar = .current
    ) -> Bool {
        guard entry.numUsers >= 2 else { return false }
        guard let ppm = daily
            .first(where: { calendar.isDate($0.loggedAt, inSameDayAs: entry.loggedAt) })?
            .primarySanitizerPpm
        else { return false }
        return entry.numUsers == Int(ppm.rounded())
    }
}
