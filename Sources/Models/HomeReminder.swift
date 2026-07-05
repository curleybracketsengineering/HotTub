//
//  HomeReminder.swift
//  HotTub
//

import Foundation

enum ReminderKind: String, Identifiable, CaseIterable {
    case dailyWaterTest
    case weeklyWaterCheck
    case filterRinse
    case filterChange
    case waterChange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyWaterTest: "Water test"
        case .weeklyWaterCheck: "Full water check"
        case .filterRinse: "Rinse filter"
        case .filterChange: "Change filter"
        case .waterChange: "Water change"
        }
    }

    func systemImage(urgency: HomeReminder.Urgency) -> String {
        switch self {
        case .dailyWaterTest:
            return urgency == .overdue ? "exclamationmark.triangle.fill" : "drop.fill"
        case .weeklyWaterCheck:
            return "calendar"
        case .filterRinse:
            return urgency == .dueToday ? "clock.fill" : "arrow.triangle.2.circlepath"
        case .filterChange:
            return "line.3.horizontal.decrease.circle.fill"
        case .waterChange:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

struct HomeReminder: Identifiable {
    let kind: ReminderKind
    let dueDate: Date
    /// When nil, the task has never been logged — show plain "Overdue" instead of a day count.
    let lastLoggedAt: Date?

    var id: String { kind.id }

    var title: String { kind.title }

    func dueSubtitle(relativeTo reference: Date = .now) -> String {
        RelativeDateFormatter.dueSubtitle(for: dueDate, relativeTo: reference)
    }

    func padSubtitle(relativeTo reference: Date = .now) -> String {
        switch urgency(relativeTo: reference) {
        case .overdue:
            if lastLoggedAt == nil {
                return "Overdue"
            }
            return RelativeDateFormatter.overdueDetail(for: dueDate, relativeTo: reference) ?? "Overdue"
        case .dueToday:
            return "Due today"
        case .upcoming:
            let delta = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: reference),
                to: Calendar.current.startOfDay(for: dueDate)
            ).day ?? 0
            let duePhrase: String
            if delta == 1 {
                duePhrase = "Due tomorrow"
            } else {
                duePhrase = "Due in \(delta) days"
            }
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("d MMM, yyyy")
            return "\(duePhrase) · \(formatter.string(from: dueDate))"
        }
    }

    func badgeLabel(relativeTo reference: Date = .now) -> String {
        switch urgency(relativeTo: reference) {
        case .overdue:
            return "Overdue"
        case .dueToday:
            return "Due today"
        case .upcoming:
            return "Upcoming"
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

    var padTitle: String { title }
}

enum ReminderSchedule {
    static let dailyInterval: TimeInterval = 24 * 60 * 60
    static let weeklyInterval: TimeInterval = 7 * 24 * 60 * 60
    static let upcomingWindowDays = 14

    static func dailyDueDate(after lastLog: Date?) -> Date {
        dueDate(after: lastLog, intervalDays: 1)
    }

    static func weeklyDueDate(after lastCheck: Date?) -> Date {
        dueDate(after: lastCheck, intervalDays: 7)
    }

    static func isDailyDue(lastLog: Date?, relativeTo reference: Date = .now) -> Bool {
        isPastDue(last: lastLog, intervalDays: 1, relativeTo: reference)
    }

    static func isWeeklyDue(lastCheck: Date?, relativeTo reference: Date = .now) -> Bool {
        isPastDue(last: lastCheck, intervalDays: 7, relativeTo: reference)
    }

    static func dueDate(after last: Date?, intervalDays: Int) -> Date {
        let cal = Calendar.current
        let base = last ?? .distantPast
        return cal.date(byAdding: .day, value: intervalDays, to: base) ?? base
    }

    static func dueDate(after last: Date?, intervalMonths: Int) -> Date {
        let cal = Calendar.current
        let base = last ?? .distantPast
        return cal.date(byAdding: .month, value: intervalMonths, to: base) ?? base
    }

    static func isPastDue(last: Date?, intervalDays: Int, relativeTo reference: Date = .now) -> Bool {
        guard let last else { return true }
        return reference >= dueDate(after: last, intervalDays: intervalDays)
    }

    static func isPastDue(last: Date?, intervalMonths: Int, relativeTo reference: Date = .now) -> Bool {
        guard let last else { return true }
        return reference >= dueDate(after: last, intervalMonths: intervalMonths)
    }

    static func shouldShow(dueDate: Date, relativeTo reference: Date = .now, windowDays: Int = upcomingWindowDays) -> Bool {
        let cal = Calendar.current
        let dayDelta = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: reference),
            to: cal.startOfDay(for: dueDate)
        ).day ?? 0
        return dayDelta <= windowDays
    }

    static func buildReminders(
        settings: AppSettings?,
        lastDaily: Date?,
        lastWeekly: Date?,
        lastFilterRinse: Date?,
        lastFilterChange: Date?,
        lastWaterChange: Date?,
        relativeTo reference: Date = .now
    ) -> [HomeReminder] {
        guard let settings else { return [] }

        var reminders: [HomeReminder] = []

        if settings.reminderWaterTestEnabled {
            let due = dueDate(after: lastDaily, intervalDays: settings.reminderWaterTestDays)
            if shouldShow(dueDate: due, relativeTo: reference) {
                reminders.append(HomeReminder(kind: .dailyWaterTest, dueDate: due, lastLoggedAt: lastDaily))
            }
        }

        if settings.reminderWeeklyCheckEnabled {
            let due = dueDate(after: lastWeekly, intervalDays: settings.reminderWeeklyCheckDays)
            if shouldShow(dueDate: due, relativeTo: reference) {
                reminders.append(HomeReminder(kind: .weeklyWaterCheck, dueDate: due, lastLoggedAt: lastWeekly))
            }
        }

        if settings.reminderFilterRinseEnabled {
            let due = dueDate(after: lastFilterRinse, intervalDays: settings.reminderFilterRinseDays)
            if shouldShow(dueDate: due, relativeTo: reference) {
                reminders.append(HomeReminder(kind: .filterRinse, dueDate: due, lastLoggedAt: lastFilterRinse))
            }
        }

        if settings.reminderFilterChangeEnabled {
            let due = dueDate(after: lastFilterChange, intervalMonths: settings.reminderFilterChangeMonths)
            if shouldShow(dueDate: due, relativeTo: reference) {
                reminders.append(HomeReminder(kind: .filterChange, dueDate: due, lastLoggedAt: lastFilterChange))
            }
        }

        if settings.reminderWaterChangeEnabled {
            let due = dueDate(after: lastWaterChange, intervalDays: settings.reminderWaterChangeDays)
            if shouldShow(dueDate: due, relativeTo: reference) {
                reminders.append(HomeReminder(kind: .waterChange, dueDate: due, lastLoggedAt: lastWaterChange))
            }
        }

        return reminders.sorted { lhs, rhs in
            let lhsUrgency = lhs.urgency(relativeTo: reference)
            let rhsUrgency = rhs.urgency(relativeTo: reference)
            let lhsRank = urgencyRank(lhsUrgency)
            let rhsRank = urgencyRank(rhsUrgency)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.dueDate < rhs.dueDate
        }
    }

    private static func urgencyRank(_ urgency: HomeReminder.Urgency) -> Int {
        switch urgency {
        case .overdue: return 0
        case .dueToday: return 1
        case .upcoming: return 2
        }
    }
}

enum MaintenanceLogPreset: String, Hashable {
    case filterRinse
    case filterChange
    case waterChange
}
