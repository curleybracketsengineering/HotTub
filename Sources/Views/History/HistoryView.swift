//
//  HistoryView.swift
//  HotTub
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    /// When `true` (History tab), title and filter share one custom header row. When `false` (pushed from Dashboard), uses the system navigation bar.
    var isTabRoot: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette

    @Query(sort: \HotTubDailyLog.loggedAt, order: .reverse) private var dailyLogs: [HotTubDailyLog]
    @Query(sort: \WeeklyCheckLog.loggedAt, order: .reverse) private var weeklyLogs: [WeeklyCheckLog]
    @Query(sort: \MaintenanceLogEntry.loggedAt, order: .reverse) private var maintenanceLogs: [MaintenanceLogEntry]
    @Query(sort: \UsageLogEntry.loggedAt, order: .reverse) private var usageLogs: [UsageLogEntry]
    @Query private var settingsRows: [AppSettings]

    @State private var filterDaily = true
    @State private var filterWeekly = true
    @State private var filterMaintenance = true
    @State private var filterUsage = true
    @State private var isFilterExpanded = false
    @State private var deleteTarget: HistoryRow?
    @State private var showDeleteConfirm = false

    private var isBromine: Bool {
        settingsRows.first?.isBromine ?? false
    }

    private var combinedRows: [HistoryRow] {
        var rows: [HistoryRow] = []
        if filterDaily { rows.append(contentsOf: dailyLogs.map { .daily($0) }) }
        if filterWeekly { rows.append(contentsOf: weeklyLogs.map { .weekly($0) }) }
        if filterMaintenance { rows.append(contentsOf: maintenanceLogs.map { .maintenance($0) }) }
        if filterUsage { rows.append(contentsOf: usageLogs.map { .usage($0) }) }

        return rows.sorted { a, b in
            if a.sortMoment != b.sortMoment { return a.sortMoment > b.sortMoment }
            return a.createdAt > b.createdAt
        }
    }

    private var daySections: [HistoryDaySection] {
        let calendar = Calendar.current
        var sections: [HistoryDaySection] = []

        for row in combinedRows {
            let day = calendar.startOfDay(for: row.sortMoment)
            if let last = sections.last, calendar.isDate(last.day, inSameDayAs: day) {
                sections[sections.count - 1] = HistoryDaySection(day: day, rows: last.rows + [row])
            } else {
                sections.append(HistoryDaySection(day: day, rows: [row]))
            }
        }
        return sections
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                if isTabRoot {
                    historyHeader
                }

                if isFilterExpanded {
                    filterChips
                }

                if combinedRows.isEmpty {
                    AppEmptyState(
                        symbol: "tray",
                        title: "No entries",
                        message: "Try turning on more filters, or tap Log on the dashboard."
                    )
                } else {
                    LazyVStack(spacing: AppSpacing.section) {
                        ForEach(daySections) { section in
                            daySection(section)
                        }
                    }
                }
            }
            .appScrollScreenPadding()
        }
        .appGroupedScreenBackground(palette)
        .modifier(HistoryNavigationChrome(isTabRoot: isTabRoot, isFilterExpanded: isFilterExpanded) {
            withAnimation(.spring(response: 0.35)) {
                isFilterExpanded.toggle()
            }
        })
        .onAppear { HotTubModelContainer.seedIfNeeded(in: modelContext) }
        .confirmationDialog("Delete this record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let row = deleteTarget { delete(row) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var historyHeader: some View {
        HStack(alignment: .center) {
            Text("History")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))
            Spacer(minLength: 12)
            AppFilterToggleButton(isExpanded: isFilterExpanded) {
                withAnimation(.spring(response: 0.35)) {
                    isFilterExpanded.toggle()
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.control) {
                AppFilterChip(title: "Daily", isOn: $filterDaily)
                AppFilterChip(title: "Weekly", isOn: $filterWeekly)
                AppFilterChip(title: "Service", isOn: $filterMaintenance)
                AppFilterChip(title: "Usage", isOn: $filterUsage)
            }
        }
        .padding(.horizontal, -AppSpacing.screenHorizontal)
        .padding(.leading, AppSpacing.screenHorizontal)
    }

    private func daySection(_ section: HistoryDaySection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            Text(RelativeDateFormatter.historySectionTitle(for: section.day))
                .font(.subheadline)
                .foregroundStyle(palette.color(.textSecondary))

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        AppSettingsDivider()
                    }
                    historyRowLink(row)
                }
            }
            .appCard(palette: palette, padding: 0)
        }
    }

    private func historyRowLink(_ row: HistoryRow) -> some View {
        NavigationLink {
            destination(for: row)
        } label: {
            ActivityRowView(row: row, isBromine: isBromine, palette: palette, showsRelativeDay: false)
                .padding(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteTarget = row
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func destination(for row: HistoryRow) -> some View {
        switch row {
        case .daily(let l): DailyLogFormView(existing: l)
        case .weekly(let l): WeeklyLogFormView(existing: l)
        case .maintenance(let l): MaintenanceLogFormView(existing: l)
        case .usage(let l): UsageLogFormView(existing: l)
        }
    }

    private func delete(_ row: HistoryRow) {
        switch row {
        case .daily(let l): modelContext.delete(l)
        case .weekly(let l): modelContext.delete(l)
        case .maintenance(let l): modelContext.delete(l)
        case .usage(let l): modelContext.delete(l)
        }
        try? modelContext.save()
        deleteTarget = nil
    }
}

private struct HistoryNavigationChrome: ViewModifier {
    let isTabRoot: Bool
    let isFilterExpanded: Bool
    let toggleFilter: () -> Void

    func body(content: Content) -> some View {
        if isTabRoot {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        AppFilterToggleButton(isExpanded: isFilterExpanded, action: toggleFilter)
                    }
                }
        }
    }
}

private struct HistoryDaySection: Identifiable {
    let day: Date
    let rows: [HistoryRow]

    var id: Date { day }
}

enum HistoryRow: Identifiable {
    case daily(HotTubDailyLog)
    case weekly(WeeklyCheckLog)
    case maintenance(MaintenanceLogEntry)
    case usage(UsageLogEntry)

    var id: String {
        switch self {
        case .daily(let x): "d-\(x.persistentModelID)"
        case .weekly(let x): "w-\(x.persistentModelID)"
        case .maintenance(let x): "m-\(x.persistentModelID)"
        case .usage(let x): "u-\(x.persistentModelID)"
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

    var createdAt: Date {
        switch self {
        case .daily(let x): return x.createdAt
        case .weekly(let x): return x.createdAt
        case .maintenance(let x): return x.createdAt
        case .usage(let x): return x.createdAt
        }
    }

    var title: String {
        switch self {
        case .daily: return "Daily log"
        case .weekly: return "Full water check"
        case .maintenance(let x): return x.action.isEmpty ? "Service" : x.action
        case .usage: return "Hot tub usage"
        }
    }
}
