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
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.isLandscape) private var isLandscape

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
    @State private var selectedRowID: String?
    @State private var selectedDay: Date?
    @State private var deleteTarget: HistoryRow?
    @State private var showDeleteConfirm = false

    private var isBromine: Bool {
        settingsRows.first?.isBromine ?? false
    }

    private var allFiltersOn: Bool {
        filterDaily && filterWeekly && filterMaintenance && filterUsage
    }

    private var allFiltersBinding: Binding<Bool> {
        Binding(
            get: { allFiltersOn },
            set: { setAllFilters($0) }
        )
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

    private var selectedRow: HistoryRow? {
        guard let selectedRowID else { return nil }
        return combinedRows.first { $0.id == selectedRowID }
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

    private var selectedDaySection: HistoryDaySection? {
        guard let selectedDay else { return nil }
        let calendar = Calendar.current
        return daySections.first { calendar.isDate($0.day, inSameDayAs: selectedDay) }
    }

    private var usesSplitLayout: Bool {
        usePadLayout && isTabRoot
    }

    /// Portrait iPad: dates in the sidebar. Landscape: full entry list.
    private var usesDateMenuSidebar: Bool {
        usesSplitLayout && !isLandscape
    }

    var body: some View {
        Group {
            if usesSplitLayout {
                padSplitBody
            } else {
                compactBody
            }
        }
        .appGroupedScreenBackground(palette)
        .onAppear {
            HotTubModelContainer.seedIfNeeded(in: modelContext)
            syncSelectionWithRows()
        }
        .onChange(of: combinedRows.map(\.id)) { _, _ in
            syncSelectionWithRows()
        }
        .onChange(of: isLandscape) { _, _ in
            syncSelectionWithRows()
        }
        .onChange(of: selectedDay) { _, _ in
            syncRowSelectionForSelectedDay()
        }
        .confirmationDialog("Delete this record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let row = deleteTarget { delete(row) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - iPad split

    private var padSplitBody: some View {
        NavigationSplitView {
            if usesDateMenuSidebar {
                portraitDateSidebar
                    .navigationSplitViewColumnWidth(
                        min: PadContentLayout.historyDateMenuMinWidth,
                        ideal: PadContentLayout.historyDateMenuIdealWidth
                    )
            } else {
                historySplitSidebar
                    .navigationSplitViewColumnWidth(
                        min: PadContentLayout.historyListMinWidth,
                        ideal: PadContentLayout.historyListIdealWidth
                    )
            }
        } detail: {
            if usesDateMenuSidebar {
                portraitDateDetail
            } else if let selectedRow {
                destination(for: selectedRow)
            } else {
                historyDetailPlaceholder
            }
        }
    }

    private var portraitDateSidebar: some View {
        List(selection: $selectedDay) {
            Section {
                padFilterChips
            }

            if daySections.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No entries", systemImage: "tray")
                    } description: {
                        Text("Try turning on more filters, or log something from Home.")
                    }
                }
            } else {
                Section {
                    ForEach(daySections) { section in
                        dateSidebarRow(section)
                            .tag(section.day)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
    }

    private func dateSidebarRow(_ section: HistoryDaySection) -> some View {
        HStack(spacing: AppSpacing.control) {
            Text(RelativeDateFormatter.historySectionTitle(for: section.day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.color(.textPrimary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text("\(section.rows.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.color(.textSecondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.color(.surfaceCard))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var portraitDateDetail: some View {
        if let section = selectedDaySection {
            if section.rows.isEmpty {
                historyDetailPlaceholder
            } else if section.rows.count == 1, let row = section.rows.first {
                destination(for: row)
            } else {
                portraitMultiEntryDetail(section)
            }
        } else {
            historyDetailPlaceholder
        }
    }

    private func portraitMultiEntryDetail(_ section: HistoryDaySection) -> some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.control) {
                    ForEach(section.rows) { row in
                        portraitEntryChip(row, isSelected: row.id == selectedRowID)
                    }
                }
                .padding(.horizontal, PadContentLayout.horizontalGutter)
                .padding(.vertical, 12)
            }
            .background(palette.color(.backgroundSecondary))

            if let selectedRow {
                destination(for: selectedRow)
            } else {
                historyDetailPlaceholder
            }
        }
    }

    private func portraitEntryChip(_ row: HistoryRow, isSelected: Bool) -> some View {
        Button {
            selectedRowID = row.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: splitRowIcon(for: row))
                    .font(.caption.weight(.semibold))
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Text(RelativeDateFormatter.timeOnly(for: row.sortMoment))
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : palette.color(.textSecondary))
            }
            .foregroundStyle(isSelected ? .white : palette.color(.textPrimary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? palette.color(.accentBlue) : palette.color(.surfaceCard))
            )
        }
        .buttonStyle(.plain)
    }

    private var historySplitSidebar: some View {
        List(selection: $selectedRowID) {
            Section {
                padFilterChips
            }

            if combinedRows.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No entries", systemImage: "tray")
                    } description: {
                        Text("Try turning on more filters, or log something from Home.")
                    }
                }
            } else {
                ForEach(daySections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            splitListRow(row)
                                .tag(row.id)
                        }
                    } header: {
                        Text(RelativeDateFormatter.historySectionTitle(for: section.day))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
    }

    private var padFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.control) {
                AppFilterChip(title: "All", isOn: allFiltersBinding)
                AppFilterChip(title: "Daily", isOn: $filterDaily)
                AppFilterChip(title: "Weekly", isOn: $filterWeekly)
                AppFilterChip(title: "Service", isOn: $filterMaintenance)
                AppFilterChip(title: "Usage", isOn: $filterUsage)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func splitListRow(_ row: HistoryRow) -> some View {
        HStack(spacing: AppSpacing.control) {
            Image(systemName: splitRowIcon(for: row))
                .font(.body.weight(.semibold))
                .foregroundStyle(splitRowAccent(for: row))
                .frame(width: 36, height: 36)
                .background(splitRowAccent(for: row).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.color(.textPrimary))
                Text(RelativeDateFormatter.timeOnly(for: row.sortMoment))
                    .font(.caption)
                    .foregroundStyle(palette.color(.textSecondary))
            }

            Spacer(minLength: 0)

            splitRowMetrics(for: row)
        }
        .contextMenu {
            deleteContextMenu(for: row)
        }
    }

    @ViewBuilder
    private func splitRowMetrics(for row: HistoryRow) -> some View {
        if case .daily(let log) = row {
            HStack(spacing: 8) {
                if let ph = log.ph {
                    Text("pH \(String(format: "%.1f", ph))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(dailyPhWarning(log) ? palette.color(.accentOrange) : palette.color(.textSecondary))
                }
                if let ppm = log.primarySanitizerPpm {
                    Text("\(isBromine ? "BR" : "CL") \(String(format: "%.1f", ppm))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(dailySanitizerWarning(log) ? palette.color(.accentOrange) : palette.color(.textSecondary))
                }
            }
        }
    }

    private var historyDetailPlaceholder: some View {
        ContentUnavailableView {
            Label(usesDateMenuSidebar ? "Select a date" : "Select a record", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text(
                usesDateMenuSidebar
                    ? "Choose a date from the list to view or edit its entries."
                    : "Choose an entry from the list to view or edit it."
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.color(.backgroundSecondary))
    }

    // MARK: - Compact (iPhone / pushed)

    private var compactBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                if isTabRoot {
                    historyHeader
                    filterChips
                } else if isFilterExpanded {
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
        .modifier(HistoryNavigationChrome(isTabRoot: isTabRoot, isFilterExpanded: isFilterExpanded) {
            withAnimation(.spring(response: 0.35)) {
                isFilterExpanded.toggle()
            }
        })
    }

    private var historyHeader: some View {
        Text("History")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(palette.color(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.control) {
                AppFilterChip(title: "All", isOn: allFiltersBinding)
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
            deleteContextMenu(for: row)
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func destination(for row: HistoryRow) -> some View {
        switch row {
        case .daily(let l): DailyLogFormView(existing: l)
        case .weekly(let l): WeeklyLogFormView(existing: l)
        case .maintenance(let l): MaintenanceLogFormView(existing: l)
        case .usage(let l): UsageLogFormView(existing: l)
        }
    }

    private func deleteContextMenu(for row: HistoryRow) -> some View {
        Button(role: .destructive) {
            deleteTarget = row
            showDeleteConfirm = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func delete(_ row: HistoryRow) {
        let deletedID = row.id
        switch row {
        case .daily(let l): modelContext.delete(l)
        case .weekly(let l): modelContext.delete(l)
        case .maintenance(let l): modelContext.delete(l)
        case .usage(let l): modelContext.delete(l)
        }
        try? modelContext.save()
        deleteTarget = nil
        if selectedRowID == deletedID {
            selectedRowID = combinedRows.first(where: { $0.id != deletedID })?.id
            if usesDateMenuSidebar {
                syncDaySelectionAfterDelete()
            }
        }
    }

    private func syncDaySelectionAfterDelete() {
        guard let currentDay = selectedDay else { return }
        let calendar = Calendar.current
        if let section = daySections.first(where: { calendar.isDate($0.day, inSameDayAs: currentDay) }) {
            if section.rows.isEmpty {
                selectedDay = daySections.first?.day
            } else if !section.rows.contains(where: { $0.id == selectedRowID }) {
                selectedRowID = section.rows.first?.id
            }
        } else {
            selectedDay = daySections.first?.day
        }
    }

    private func setAllFilters(_ on: Bool) {
        filterDaily = on
        filterWeekly = on
        filterMaintenance = on
        filterUsage = on
    }

    private func syncSelectionWithRows() {
        guard usesSplitLayout else { return }
        if usesDateMenuSidebar {
            syncDaySelection()
        } else {
            syncRowSelection()
        }
    }

    private func syncDaySelection() {
        if daySections.isEmpty {
            selectedDay = nil
            selectedRowID = nil
        } else if selectedDay == nil
            || !daySections.contains(where: { Calendar.current.isDate($0.day, inSameDayAs: selectedDay!) })
        {
            selectedDay = daySections.first?.day
        }
        syncRowSelectionForSelectedDay()
    }

    private func syncRowSelection() {
        if combinedRows.isEmpty {
            selectedRowID = nil
        } else if selectedRowID == nil || !combinedRows.contains(where: { $0.id == selectedRowID }) {
            selectedRowID = combinedRows.first?.id
        }
    }

    private func syncRowSelectionForSelectedDay() {
        guard usesDateMenuSidebar else { return }
        guard let section = selectedDaySection else {
            selectedRowID = nil
            return
        }
        if section.rows.isEmpty {
            selectedRowID = nil
        } else if selectedRowID == nil || !section.rows.contains(where: { $0.id == selectedRowID }) {
            selectedRowID = section.rows.first?.id
        }
    }

    private func splitRowIcon(for row: HistoryRow) -> String {
        switch row {
        case .weekly: "checkmark.circle.fill"
        default: row.kind.systemImage
        }
    }

    private func splitRowAccent(for row: HistoryRow) -> Color {
        switch row {
        case .weekly: palette.color(.accentGreen)
        default: palette.color(row.kind.iconToken)
        }
    }

    private func dailyPhWarning(_ log: HotTubDailyLog) -> Bool {
        guard let ph = log.ph else { return false }
        return ph < 7.2 || ph > 7.8
    }

    private func dailySanitizerWarning(_ log: HotTubDailyLog) -> Bool {
        guard let ppm = log.primarySanitizerPpm else { return false }
        if isBromine { return ppm < 3.0 || ppm > 5.0 }
        return ppm < 1.0 || ppm > 3.0
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
