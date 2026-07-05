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
}
