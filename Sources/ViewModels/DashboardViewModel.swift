//
//  DashboardViewModel.swift
//  HotTub
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
    /// Home preview count — full history lives on the History tab.
    static let recentRecordsLimit = 3

    @Published private(set) var latestDailyLog: HotTubDailyLog?
    @Published private(set) var latestWeeklyLog: WeeklyCheckLog?
    @Published private(set) var recentRecords: [DashboardActivity] = []
    @Published private(set) var dueReminders: [HomeReminder] = []
    @Published private(set) var isBromine: Bool = false

    func reload(context: ModelContext) {
        objectWillChange.send()
        HotTubModelContainer.seedIfNeeded(in: context)

        let daily = (try? context.fetch(FetchDescriptor<HotTubDailyLog>())) ?? []
        let weekly = (try? context.fetch(FetchDescriptor<WeeklyCheckLog>())) ?? []
        let maintenance = (try? context.fetch(FetchDescriptor<MaintenanceLogEntry>())) ?? []
        let usage = (try? context.fetch(FetchDescriptor<UsageLogEntry>())) ?? []
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        let settings = settingsList.first

        latestDailyLog = HistorySorting.mostRecentDailyLog(daily)
        latestWeeklyLog = HistorySorting.mostRecentWeeklyLog(weekly)
        let maintenanceDates = ReminderSchedule.lastMaintenanceDates(from: maintenance)

        isBromine = settings?.isBromine ?? false

        var allRecords: [DashboardActivity] = []
        allRecords.append(contentsOf: daily.map { .daily($0) })
        allRecords.append(contentsOf: weekly.map { .weekly($0) })
        allRecords.append(contentsOf: maintenance.map { .maintenance($0) })
        allRecords.append(contentsOf: usage.map { .usage($0) })

        allRecords.sort { a, b in
            HistorySorting.momentSortsBefore(
                loggedAt: a.sortMoment,
                createdAt: a.createdAtMoment,
                loggedAt: b.sortMoment,
                createdAt: b.createdAtMoment
            )
        }
        recentRecords = Array(allRecords.prefix(Self.recentRecordsLimit))

        dueReminders = ReminderSchedule.buildReminders(
            settings: settings,
            lastDaily: latestDailyLog?.loggedAt,
            lastWeekly: latestWeeklyLog?.loggedAt,
            lastFilterRinse: maintenanceDates.filterRinse,
            lastFilterChange: maintenanceDates.filterChange,
            lastWaterChange: maintenanceDates.waterChange
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

    /// Short hero headline for the dashboard status card.
    func heroHeadline(ph: Double?, sanitizer: Double?, hasData: Bool, isDailyDue: Bool) -> String {
        if !hasData { return "Check your water today" }
        if isDailyDue { return "Water test due today" }
        if readingsAreBalanced(ph: ph, sanitizer: sanitizer) { return "Water looks good" }
        if phOutOfRange(ph), sanitizerOutOfRange(sanitizer) { return "Water needs attention" }
        if phOutOfRange(ph) { return "pH needs attention" }
        return "\(isBromine ? "Bromine" : "Chlorine") needs attention"
    }

    func readingsAreBalanced(ph: Double?, sanitizer: Double?) -> Bool {
        !phOutOfRange(ph) && !sanitizerOutOfRange(sanitizer)
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

    /// True when the latest daily log is more than the configured interval old.
    var readingsAreStale: Bool {
        guard let lastDaily = latestDailyLog?.loggedAt else { return false }
        return ReminderSchedule.isDailyDue(lastLog: lastDaily)
    }
}
