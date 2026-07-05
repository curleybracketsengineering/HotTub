//
//  HistorySorting.swift
//  HotTub
//

import Foundation

enum HistorySorting {
    /// `true` when row `a` should appear above row `b` (most recent real history first).
    /// Past and today sort newest-first; future-dated logs sink below real history.
    static func momentSortsBefore(
        loggedAt a: Date,
        createdAt aCreated: Date,
        loggedAt b: Date,
        createdAt bCreated: Date
    ) -> Bool {
        let aIsFuture = FormValidation.isFutureLoggedDay(a)
        let bIsFuture = FormValidation.isFutureLoggedDay(b)
        if aIsFuture != bIsFuture { return !aIsFuture }
        if a != b { return a > b }
        return aCreated > bCreated
    }

    /// `true` when day `a` should appear above day `b` in grouped history sections.
    /// Expects calendar start-of-day values for `a` and `b`.
    static func daySortsBefore(_ a: Date, _ b: Date) -> Bool {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let aIsFuture = a > todayStart
        let bIsFuture = b > todayStart
        if aIsFuture != bIsFuture { return !aIsFuture }
        return a > b
    }

    /// Most recent log by `loggedAt`, matching History tab ordering (future dates sink below real history).
    static func mostRecentDailyLog(_ logs: [HotTubDailyLog]) -> HotTubDailyLog? {
        logs.min { a, b in
            momentSortsBefore(
                loggedAt: a.loggedAt,
                createdAt: a.createdAt,
                loggedAt: b.loggedAt,
                createdAt: b.createdAt
            )
        }
    }

    /// Most recent weekly check by `loggedAt`, matching History tab ordering.
    static func mostRecentWeeklyLog(_ logs: [WeeklyCheckLog]) -> WeeklyCheckLog? {
        logs.min { a, b in
            momentSortsBefore(
                loggedAt: a.loggedAt,
                createdAt: a.createdAt,
                loggedAt: b.loggedAt,
                createdAt: b.createdAt
            )
        }
    }
}
