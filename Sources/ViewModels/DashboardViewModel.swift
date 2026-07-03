//
//  DashboardViewModel.swift
//  HotTub Buddy
//

import Combine
import Foundation
import SwiftData
import SwiftUI

enum DashboardActivity: Identifiable {
    case daily(HotTubDailyLog)
    case weekly(WeeklyCheckLog)
    case maintenance(MaintenanceLogEntry)
    case usage(UsageLogEntry)

    var id: PersistentIdentifier {
        switch self {
        case .daily(let x): x.persistentModelID
        case .weekly(let x): x.persistentModelID
        case .maintenance(let x): x.persistentModelID
        case .usage(let x): x.persistentModelID
        }
    }

    var sortMoment: Date {
        switch self {
        case .daily(let x): return x.loggedAt
        case .weekly(let x): return x.loggedAt
        case .maintenance(let x): return x.loggedAt
        case .usage(let x): return x.loggedAt
        }
    }

    var createdAtMoment: Date {
        switch self {
        case .daily(let x): return x.createdAt
        case .weekly(let x): return x.createdAt
        case .maintenance(let x): return x.createdAt
        case .usage(let x): return x.createdAt
        }
    }

    var title: String {
        historyRow.title
    }

    var accentToken: PaletteToken {
        switch self {
        case .daily, .weekly: return .accentBlue
        case .maintenance: return .accentOrange
        case .usage: return .accentGreen
        }
    }

    var historyRow: HistoryRow {
        switch self {
        case .daily(let log): return .daily(log)
        case .weekly(let log): return .weekly(log)
        case .maintenance(let log): return .maintenance(log)
        case .usage(let log): return .usage(log)
        }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var latestDailyLog: HotTubDailyLog?
    @Published private(set) var latestWeeklyLog: WeeklyCheckLog?
    @Published private(set) var recentRecords: [DashboardActivity] = []
    @Published private(set) var dueReminders: [HomeReminder] = []
    @Published private(set) var isBromine: Bool = false

    func reload(context: ModelContext) {
        HotTubModelContainer.seedIfNeeded(in: context)

        let daily = (try? context.fetch(FetchDescriptor<HotTubDailyLog>())) ?? []
        let weekly = (try? context.fetch(FetchDescriptor<WeeklyCheckLog>())) ?? []
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        let settings = settingsList.first

        let sortedDaily = daily.sorted { $0.loggedAt > $1.loggedAt }
        let sortedWeekly = weekly.sorted { $0.loggedAt > $1.loggedAt }
        latestDailyLog = sortedDaily.first
        latestWeeklyLog = sortedWeekly.first

        isBromine = settings?.isBromine ?? false

        var waterRecords: [DashboardActivity] = []
        waterRecords.append(contentsOf: daily.map { .daily($0) })
        waterRecords.append(contentsOf: weekly.map { .weekly($0) })

        waterRecords.sort { a, b in
            if a.sortMoment != b.sortMoment { return a.sortMoment > b.sortMoment }
            return a.createdAtMoment > b.createdAtMoment
        }
        recentRecords = Array(waterRecords.prefix(3))

        dueReminders = buildDueReminders(
            lastDaily: latestDailyLog?.loggedAt,
            lastWeekly: latestWeeklyLog?.loggedAt
        )
    }

    func delete(_ item: DashboardActivity, context: ModelContext) {
        switch item {
        case .daily(let l): context.delete(l)
        case .weekly(let l): context.delete(l)
        case .maintenance(let l): context.delete(l)
        case .usage(let l): context.delete(l)
        }
        try? context.save()
        reload(context: context)
    }

    /// Neutral summary of last readings vs typical reference ranges — not treatment advice.
    func statusSummary(ph: Double?, sanitizer: Double?) -> String {
        if ph == nil && sanitizer == nil { return "No readings logged" }
        let phOk = ph.map { $0 >= 7.2 && $0 <= 7.8 } ?? false
        let sanitizerOk: Bool
        if isBromine {
            sanitizerOk = sanitizer.map { $0 >= 3.0 && $0 <= 5.0 } ?? false
        } else {
            sanitizerOk = sanitizer.map { $0 >= 1.0 && $0 <= 3.0 } ?? false
        }
        let sanitizerShort = isBromine ? "bromine" : "CH"
        if phOk && sanitizerOk { return "Within typical range" }
        if !phOk && !sanitizerOk { return "pH and \(sanitizerShort) outside typical range" }
        if !phOk { return "pH outside typical range" }
        return "\(isBromine ? "Bromine" : "CH") outside typical range"
    }

    func sanitizerOutOfRange(_ ppm: Double?) -> Bool {
        guard let ppm else { return false }
        if isBromine { return ppm < 3.0 || ppm > 5.0 }
        return ppm < 1.0 || ppm > 3.0
    }

    func phOutOfRange(_ ph: Double?) -> Bool {
        guard let ph else { return false }
        return ph < 7.2 || ph > 7.8
    }

    /// True when the latest daily log is more than 24 hours old.
    var readingsAreStale: Bool {
        guard let lastDaily = latestDailyLog?.loggedAt else { return false }
        return ReminderSchedule.isDailyDue(lastLog: lastDaily)
    }

    private func buildDueReminders(lastDaily: Date?, lastWeekly: Date?) -> [HomeReminder] {
        var reminders: [HomeReminder] = []

        if ReminderSchedule.isDailyDue(lastLog: lastDaily) {
            reminders.append(
                HomeReminder(
                    kind: .dailyWaterTest,
                    dueDate: ReminderSchedule.dailyDueDate(after: lastDaily)
                )
            )
        }

        if ReminderSchedule.isWeeklyDue(lastCheck: lastWeekly) {
            reminders.append(
                HomeReminder(
                    kind: .weeklyWaterCheck,
                    dueDate: ReminderSchedule.weeklyDueDate(after: lastWeekly)
                )
            )
        }

        return reminders.sorted { $0.dueDate < $1.dueDate }
    }
}
