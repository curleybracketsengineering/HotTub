//
//  HomeReminder.swift
//  HotTub
//

import Foundation

enum ReminderKind: String, Identifiable {
    case dailyWaterTest
    case weeklyWaterCheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyWaterTest: "Daily water test"
        case .weeklyWaterCheck: "Weekly water check"
        }
    }
}

struct HomeReminder: Identifiable {
    let kind: ReminderKind
    let dueDate: Date

    var id: String { kind.id }

    var title: String { kind.title }

    func dueSubtitle(relativeTo reference: Date = .now) -> String {
        RelativeDateFormatter.dueSubtitle(for: dueDate, relativeTo: reference)
    }
}

enum ReminderSchedule {
    static let dailyInterval: TimeInterval = 24 * 60 * 60
    static let weeklyInterval: TimeInterval = 7 * 24 * 60 * 60

    static func dailyDueDate(after lastLog: Date?) -> Date {
        let base = lastLog ?? .distantPast
        return base.addingTimeInterval(dailyInterval)
    }

    static func weeklyDueDate(after lastCheck: Date?) -> Date {
        let base = lastCheck ?? .distantPast
        return base.addingTimeInterval(weeklyInterval)
    }

    static func isDailyDue(lastLog: Date?, relativeTo reference: Date = .now) -> Bool {
        guard let lastLog else { return true }
        return reference.timeIntervalSince(lastLog) > dailyInterval
    }

    static func isWeeklyDue(lastCheck: Date?, relativeTo reference: Date = .now) -> Bool {
        guard let lastCheck else { return true }
        return reference.timeIntervalSince(lastCheck) > weeklyInterval
    }
}
