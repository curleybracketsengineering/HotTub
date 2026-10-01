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
    @Published private(set) var phTarget: ClosedRange<Double> = WaterChemistryRanges.startingPH
    @Published private(set) var sanitizerTarget: ClosedRange<Double> = WaterChemistryRanges.startingChlorine

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
        phTarget = settings?.phTarget ?? WaterChemistryRanges.startingPH
        sanitizerTarget = settings?.sanitizerTarget
            ?? (isBromine ? WaterChemistryRanges.startingBromine : WaterChemistryRanges.startingChlorine)

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

    var sanitizerReadingName: String {
        isBromine ? "Bromine" : "Free chlorine"
    }

    var phDisplayRange: ClosedRange<Double> {
        WaterChemistryRanges.displayRange(covering: phTarget, fallback: WaterChemistryRanges.phDisplay)
    }

    var sanitizerDisplayRange: ClosedRange<Double> {
        let fallback = isBromine ? WaterChemistryRanges.bromineDisplay : WaterChemistryRanges.chlorineDisplay
        return WaterChemistryRanges.displayRange(covering: sanitizerTarget, fallback: fallback)
    }

    func phStatus(_ ph: Double?) -> RangeStatus {
        RangeStatus(value: ph, target: phTarget)
    }

    func sanitizerStatus(_ ppm: Double?) -> RangeStatus {
        RangeStatus(value: ppm, target: sanitizerTarget)
    }

    /// Hero copy for the latest daily readings. An out-of-range value outranks a due reminder.
    func homeStatus(log: HotTubDailyLog?) -> HomeStatusPresentation {
        let phValue = log?.ph
        let sanitizerValue = log?.primarySanitizerPpm
        let phState = phStatus(phValue)
        let sanitizerState = sanitizerStatus(sanitizerValue)
        let hasData = log != nil
        let isDue = hasData && readingsAreStale
        let outside = outsideReadings(ph: phState, sanitizer: sanitizerState)

        let headline: String
        let dueSecondary: String?
        if outside.count > 1 {
            headline = "Some readings are outside your target ranges"
            dueSecondary = isDue ? "Water test due today" : nil
        } else if let only = outside.first {
            headline = "\(only.name) is \(only.status.relationPhrase)"
            dueSecondary = isDue ? "Water test due today" : nil
        } else if !hasData {
            headline = "No readings recorded yet"
            dueSecondary = nil
        } else if phState == .unknown && sanitizerState == .unknown {
            headline = "No chemistry readings recorded"
            dueSecondary = isDue ? "Water test due today" : nil
        } else if isDue {
            headline = "Water test due today"
            dueSecondary = nil
        } else {
            headline = "All recorded readings are within your target ranges"
            dueSecondary = nil
        }

        let subtitle: String?
        if let log {
            subtitle = "Last water test \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))"
        } else {
            subtitle = nil
        }

        let readingsOutsideTarget = !outside.isEmpty
        return HomeStatusPresentation(
            headline: headline,
            subtitle: subtitle,
            comparisonCaption: "Compared with the targets you saved",
            dueSecondary: dueSecondary,
            footer: readingsOutsideTarget
                ? "Use your manufacturer and chemical product guidance when deciding what to do next."
                : "This app records your readings and compares them with the targets you saved.",
            readingsOutsideTarget: readingsOutsideTarget,
            hasData: hasData,
            isDue: isDue,
            ph: HomeReadingPresentation(
                name: "pH",
                valueText: phValue.map { String(format: "%.1f", $0) } ?? "--",
                target: phTarget,
                unit: "",
                status: phState,
                displayRange: phDisplayRange
            ),
            sanitizer: HomeReadingPresentation(
                name: sanitizerReadingName,
                valueText: sanitizerValue.map { String(format: "%.1f ppm", $0) } ?? "-- ppm",
                target: sanitizerTarget,
                unit: "ppm",
                status: sanitizerState,
                displayRange: sanitizerDisplayRange
            )
        )
    }

    private func outsideReadings(ph: RangeStatus, sanitizer: RangeStatus) -> [(name: String, status: RangeStatus)] {
        var rows: [(name: String, status: RangeStatus)] = []
        if sanitizer.isOutsideTarget {
            rows.append((sanitizerReadingName, sanitizer))
        }
        if ph.isOutsideTarget {
            rows.append(("pH", ph))
        }
        return rows
    }

    /// True when the latest daily log is more than the configured interval old.
    var readingsAreStale: Bool {
        guard let lastDaily = latestDailyLog?.loggedAt else { return false }
        return ReminderSchedule.isDailyDue(lastLog: lastDaily)
    }
}

struct HomeReadingPresentation: Equatable {
    let name: String
    let valueText: String
    let target: ClosedRange<Double>
    let unit: String
    let status: RangeStatus
    let displayRange: ClosedRange<Double>

    var accessibilityText: String {
        let targetBounds = "\(WaterChemistryRanges.formatBound(target.lowerBound)) to \(WaterChemistryRanges.formatBound(target.upperBound))"
        switch status {
        case .unknown:
            return "\(name), no reading recorded. Your saved target is \(targetBounds)\(unit == "ppm" ? " parts per million" : "")."
        case .below, .within, .above:
            let spokenValue = unit == "ppm"
                ? valueText.replacingOccurrences(of: "ppm", with: "parts per million")
                : valueText
            let relation = status == .within
                ? "within"
                : (status == .below ? "below" : "above")
            return "\(name) \(spokenValue), \(relation) your saved target of \(targetBounds)\(unit == "ppm" ? " parts per million" : "")."
        }
    }
}

struct HomeStatusPresentation: Equatable {
    let headline: String
    let subtitle: String?
    let comparisonCaption: String
    let dueSecondary: String?
    let footer: String
    let readingsOutsideTarget: Bool
    let hasData: Bool
    let isDue: Bool
    let ph: HomeReadingPresentation
    let sanitizer: HomeReadingPresentation
}
