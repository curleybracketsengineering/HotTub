//
//  RelativeDateFormatter.swift
//  HotTub Buddy
//

import Foundation

enum RelativeDateFormatter {
    private static let calendar = Calendar.current

    private static let shortMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f
    }()

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("jm")
        return f
    }()

    /// "Today", "Yesterday", or short date like "Jun 26".
    static func relativeDay(for date: Date, relativeTo reference: Date = .now) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return shortMonthDay.string(from: date)
    }

    /// "Today, 9:15 AM" style timestamp for list rows and hero pill.
    static func relativeDayAndTime(for date: Date, relativeTo reference: Date = .now) -> String {
        "\(relativeDay(for: date, relativeTo: reference)), \(time.string(from: date))"
    }

    /// Due subtitle for reminders: "Due today", "Due tomorrow", "Due in N days", "Overdue".
    static func dueSubtitle(for dueDate: Date, relativeTo reference: Date = .now) -> String {
        let startOfReference = calendar.startOfDay(for: reference)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let dayDelta = calendar.dateComponents([.day], from: startOfReference, to: startOfDue).day ?? 0

        switch dayDelta {
        case ..<0:
            return "Overdue"
        case 0:
            return "Due today"
        case 1:
            return "Due tomorrow"
        default:
            return "Due in \(dayDelta) days"
        }
    }
}
