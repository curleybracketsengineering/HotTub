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

    func padSubtitle(relativeTo reference: Date = .now) -> String {
        if let overdue = RelativeDateFormatter.overdueDetail(for: dueDate, relativeTo: reference) {
            return overdue
        }
        switch urgency(relativeTo: reference) {
        case .dueToday:
            return "Due today"
        case .upcoming:
            let delta = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: reference),
                to: Calendar.current.startOfDay(for: dueDate)
            ).day ?? 0
            if delta == 1 { return "Due tomorrow" }
            return "Due in \(delta) days"
        case .overdue:
            return RelativeDateFormatter.overdueDetail(for: dueDate, relativeTo: reference) ?? "Overdue"
        }
    }

    func badgeLabel(relativeTo reference: Date = .now) -> String {
        switch urgency(relativeTo: reference) {
        case .overdue:
            return "Overdue"
        case .dueToday:
            return "Due today"
        case .upcoming:
            return RelativeDateFormatter.dueBadgeDate(for: dueDate)
        }
    }

    enum Urgency {
        case overdue
        case dueToday
        case upcoming
    }

    func urgency(relativeTo reference: Date = .now) -> Urgency {
        let cal = Calendar.current
        let dayDelta = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: reference),
            to: cal.startOfDay(for: dueDate)
        ).day ?? 0
        if dayDelta < 0 { return .overdue }
        if dayDelta == 0 { return .dueToday }
        return .upcoming
    }

    var padTitle: String {
        switch kind {
        case .dailyWaterTest: "Water test"
        case .weeklyWaterCheck: "Weekly water check"
        }
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
