//
//  RateCalculator.swift
//  HotTub
//
//  Port of React rateCalculator.js for sanitizer consumption estimates.
//

import Foundation

struct UsageRatePeriod: Sendable {
    /// Start of the local calendar day for the earlier reading in the pair.
    var periodStart: Date
    /// Start of the local calendar day for the later reading in the pair.
    var periodEnd: Date
    var hoursElapsed: Double
    var daysElapsed: Double
    var ppmPerDay: Double
    var gramsPerDay: Double
    var excludedFromCalc: Bool
    var exclusionReason: String?
}

struct AverageRateResult: Sendable {
    var days: Int
    var sampleSize: Int
    var avgPpmPerDay: Double
    var avgGramsPerDay: Double
}

struct DataConfidence: Sendable {
    var hasRecentWaterChange: Bool
    /// Start of the local calendar day when water was last changed, if known.
    var waterChangeDate: Date?
    var daysSinceWaterChange: Int?
    var readingsSinceWaterChange: Int
    var confidence: String
    var warningMessage: String?
}

enum RateCalculator {
    private static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func ymdString(_ date: Date, calendar: Calendar = .current) -> String {
        let d = startOfDay(date, calendar: calendar)
        let y = calendar.component(.year, from: d)
        let m = calendar.component(.month, from: d)
        let day = calendar.component(.day, from: d)
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    private static func mostRecentWaterChangeDay(from maintenance: [MaintenanceLogEntry]) -> Date? {
        maintenance
            .filter(\.waterChange)
            .map { startOfDay($0.loggedAt) }
            .max()
    }

    static func calculateUsageRates(
        logs: [HotTubDailyLog],
        volumeLitres: Double,
        weeklyChecks: [WeeklyCheckLog],
        maintenanceLogs: [MaintenanceLogEntry],
        isBromine: Bool = false
    ) -> [UsageRatePeriod] {
        guard logs.count >= 2 else { return [] }

        let waterChangeDay = mostRecentWaterChangeDay(from: maintenanceLogs)
        let cal = Calendar.current
        let filtered: [HotTubDailyLog]
        if let waterChangeDay {
            filtered = logs.filter { startOfDay($0.loggedAt, calendar: cal) > waterChangeDay }
        } else {
            filtered = logs
        }
        guard filtered.count >= 2 else { return [] }

        let sortedLogs = filtered.sorted { $0.loggedAt < $1.loggedAt }

        var rates: [UsageRatePeriod] = []

        for i in 1..<sortedLogs.count {
            let before = sortedLogs[i - 1]
            let after = sortedLogs[i]
            guard let c1 = before.sanitizerFree, let c2 = after.sanitizerFree else { continue }

            let beforeTime = before.loggedAt
            let afterTime = after.loggedAt

            let hoursElapsed = afterTime.timeIntervalSince(beforeTime) / 3600
            if hoursElapsed <= 0 { continue }

            let beforeYmd = ymdString(beforeTime, calendar: cal)
            let afterYmd = ymdString(afterTime, calendar: cal)

            let chlorineShockInPeriod = weeklyChecks.contains { check in
                let d = ymdString(check.loggedAt, calendar: cal)
                return d >= beforeYmd && d <= afterYmd
                    && (check.shockAdded ?? 0) > 0
                    && ShockTypes.isSanitizerAddingShock(check.shockType)
            }

            let ppmChange = c1 - c2
            let ppmAdded = after.addedSanitizer
            let totalConsumed = ppmChange + ppmAdded
            let ppmPerHour = totalConsumed / hoursElapsed
            let ppmPerDay = ppmPerHour * 24
            let gramsPerDay = (ppmPerDay * volumeLitres) / 1000 / 0.62

            rates.append(
                UsageRatePeriod(
                    periodStart: startOfDay(beforeTime, calendar: cal),
                    periodEnd: startOfDay(afterTime, calendar: cal),
                    hoursElapsed: (hoursElapsed * 10).rounded() / 10,
                    daysElapsed: ((hoursElapsed / 24) * 10).rounded() / 10,
                    ppmPerDay: (ppmPerDay * 100).rounded() / 100,
                    gramsPerDay: (gramsPerDay * 100).rounded() / 100,
                    excludedFromCalc: chlorineShockInPeriod,
                    exclusionReason: chlorineShockInPeriod
                        ? "\(isBromine ? "Bromine" : "Chlorine")-based shock applied in this period"
                        : nil
                )
            )
        }
        return rates
    }

    static func getCurrentRate(
        logs: [HotTubDailyLog],
        volumeLitres: Double,
        weeklyChecks: [WeeklyCheckLog],
        maintenanceLogs: [MaintenanceLogEntry],
        isBromine: Bool = false
    ) -> UsageRatePeriod? {
        let rates = calculateUsageRates(
            logs: logs,
            volumeLitres: volumeLitres,
            weeklyChecks: weeklyChecks,
            maintenanceLogs: maintenanceLogs,
            isBromine: isBromine
        )
        let valid = rates.filter { !$0.excludedFromCalc }
        return valid.last
    }

    static func getAverageRate(
        logs: [HotTubDailyLog],
        volumeLitres: Double,
        days: Int = 7,
        weeklyChecks: [WeeklyCheckLog],
        maintenanceLogs: [MaintenanceLogEntry],
        isBromine: Bool = false
    ) -> AverageRateResult? {
        let rates = calculateUsageRates(
            logs: logs,
            volumeLitres: volumeLitres,
            weeklyChecks: weeklyChecks,
            maintenanceLogs: maintenanceLogs,
            isBromine: isBromine
        )
        guard !rates.isEmpty else { return nil }

        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffDay = startOfDay(cutoff, calendar: cal)

        let recent = rates.filter { $0.periodEnd >= cutoffDay && !$0.excludedFromCalc }
        guard !recent.isEmpty else { return nil }

        let avgPpm = recent.map(\.ppmPerDay).reduce(0, +) / Double(recent.count)
        let avgGrams = recent.map(\.gramsPerDay).reduce(0, +) / Double(recent.count)
        return AverageRateResult(
            days: days,
            sampleSize: recent.count,
            avgPpmPerDay: (avgPpm * 100).rounded() / 100,
            avgGramsPerDay: (avgGrams * 100).rounded() / 100
        )
    }

    static func getDataConfidence(
        logs: [HotTubDailyLog],
        maintenanceLogs: [MaintenanceLogEntry]
    ) -> DataConfidence {
        let waterChangeDay = mostRecentWaterChangeDay(from: maintenanceLogs)

        guard let waterChangeDay else {
            let n = logs.count
            let conf: String
            if n >= 7 { conf = "high" }
            else if n >= 3 { conf = "medium" }
            else { conf = "low" }
            return DataConfidence(
                hasRecentWaterChange: false,
                waterChangeDate: nil,
                daysSinceWaterChange: nil,
                readingsSinceWaterChange: n,
                confidence: conf,
                warningMessage: nil
            )
        }

        let cal = Calendar.current
        let logsAfter = logs.filter { startOfDay($0.loggedAt, calendar: cal) > waterChangeDay }
        let daysSince = cal.dateComponents([.day], from: waterChangeDay, to: startOfDay(Date(), calendar: cal)).day ?? 0

        var confidence = "low"
        var warning: String?

        if logsAfter.count < 2 {
            confidence = "insufficient"
            warning = "Need at least 2 readings after water change for consumption estimates"
        } else if daysSince < 7 || logsAfter.count < 5 {
            confidence = "low"
            warning = "Recent water change - consumption rates may be less stable than normal"
        } else {
            confidence = "medium"
        }

        return DataConfidence(
            hasRecentWaterChange: true,
            waterChangeDate: waterChangeDay,
            daysSinceWaterChange: daysSince,
            readingsSinceWaterChange: logsAfter.count,
            confidence: confidence,
            warningMessage: warning
        )
    }
}
