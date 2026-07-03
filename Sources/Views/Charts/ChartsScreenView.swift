//
//  ChartsScreenView.swift
//  HotTub Buddy
//

import Charts
import Combine
import SwiftData
import SwiftUI

private struct ChartPoint: Identifiable {
    let id: PersistentIdentifier
    let day: Date
    let value: Double
}

private struct UserBarPoint: Identifiable {
    let id: String
    let day: Date
    let count: Int
}

private enum ChartRange: String, CaseIterable {
    case last7Days = "7 days"
    case month = "Month"
}

struct ChartsScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette

    @Query(sort: \HotTubDailyLog.loggedAt, order: .forward) private var allDaily: [HotTubDailyLog]
    @Query(sort: \UsageLogEntry.loggedAt, order: .forward) private var allUsage: [UsageLogEntry]
    @Query private var settingsRows: [AppSettings]

    @State private var chartRange: ChartRange = .month
    @State private var viewMonth: Date = Date()
    /// Monday starting the visible calendar week (7-day window ends that Sunday or today).
    @State private var sevenDayWeekStart: Date = ChartsWeekCalendar.mondayContaining(Date())
    @State private var showSanitizer = true
    @State private var showPH = true
    @State private var showUsers = true

    private var isBromine: Bool {
        settingsRows.first?.isBromine ?? false
    }

    private var sanitizerLabel: String {
        isBromine ? "Bromine" : "Chlorine"
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: viewMonth)
    }

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var last7DaysStart: Date {
        Calendar.current.startOfDay(for: sevenDayWeekStart)
    }

    private var last7DaysEnd: Date {
        ChartsWeekCalendar.weekEnd(forWeekStarting: sevenDayWeekStart, cappedTo: todayStart)
    }

    private var currentWeekMonday: Date {
        ChartsWeekCalendar.mondayContaining(todayStart)
    }

    private var canAdvanceSevenDayWindow: Bool {
        sevenDayWeekStart < currentWeekMonday
    }

    private var viewMonthStart: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: viewMonth))
            ?? cal.startOfDay(for: viewMonth)
    }

    private var monthPickerOptions: [Date] {
        let cal = Calendar.current
        guard let earliest = cal.date(byAdding: .month, value: -35, to: todayStart),
              var cursor = cal.date(from: cal.dateComponents([.year, .month], from: earliest))
        else { return [viewMonthStart] }

        let latest = cal.date(from: cal.dateComponents([.year, .month], from: todayStart)) ?? todayStart
        var months: [Date] = []
        while cursor <= latest {
            months.append(cursor)
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }

    private var weekPickerOptions: [Date] {
        let cal = Calendar.current
        let currentMonday = currentWeekMonday
        let usageMondays = allUsage.map { ChartsWeekCalendar.mondayContaining($0.loggedAt) }
        let dailyMondays = allDaily.map { ChartsWeekCalendar.mondayContaining($0.loggedAt) }
        let dataEarliest = (usageMondays + dailyMondays).min()
        let defaultEarliest = cal.date(byAdding: .weekOfYear, value: -52, to: currentMonday) ?? currentMonday
        let earliestMonday = dataEarliest.map { min($0, currentMonday) } ?? defaultEarliest

        var mondays: [Date] = []
        var monday = currentMonday
        while monday >= earliestMonday {
            mondays.append(monday)
            guard let prev = cal.date(byAdding: .day, value: -7, to: monday) else { break }
            monday = prev
        }
        return mondays
    }

    private var last7DaysLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: last7DaysStart)) – \(f.string(from: last7DaysEnd))"
    }

    private func isInChartRange(_ date: Date) -> Bool {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        switch chartRange {
        case .last7Days:
            return day >= last7DaysStart && day <= last7DaysEnd
        case .month:
            return cal.isDate(day, equalTo: viewMonth, toGranularity: .month)
        }
    }

    private var chartXDomain: ClosedRange<Date> {
        let cal = Calendar.current
        switch chartRange {
        case .last7Days:
            return last7DaysStart ... last7DaysEnd
        case .month:
            guard let interval = cal.dateInterval(of: .month, for: viewMonth) else {
                let today = todayStart
                return today ... today
            }
            let monthEnd = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
            return cal.startOfDay(for: interval.start) ... cal.startOfDay(for: monthEnd)
        }
    }

    /// One mark per day in the 7-day window (explicit dates avoid extra grid lines from `.stride`).
    private var sevenDayMarkDates: [Date] {
        let cal = Calendar.current
        var dates: [Date] = []
        var day = last7DaysStart
        while day <= last7DaysEnd {
            dates.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return dates
    }

    /// Mondays in the viewed month — one vertical line / label per week.
    private var monthMondayMarkDates: [Date] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: viewMonth) else { return [] }
        var dates: [Date] = []
        var day = cal.startOfDay(for: interval.start)
        while day < interval.end {
            if cal.component(.weekday, from: day) == 2 {
                dates.append(day)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return dates
    }

    private var xAxisMarkDates: [Date] {
        chartRange == .month ? monthMondayMarkDates : sevenDayMarkDates
    }

    private var filteredDailyLogs: [HotTubDailyLog] {
        allDaily.filter { isInChartRange($0.loggedAt) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    private var filteredUsageLogs: [UsageLogEntry] {
        allUsage.filter { isInChartRange($0.loggedAt) }
    }

    private var phMarks: [ChartPoint] {
        let cal = Calendar.current
        return filteredDailyLogs.compactMap { log in
            guard let ph = log.ph else { return nil }
            let day = cal.startOfDay(for: log.loggedAt)
            return ChartPoint(id: log.persistentModelID, day: day, value: ph)
        }
    }

    private var sanitizerMarks: [ChartPoint] {
        let cal = Calendar.current
        return filteredDailyLogs.compactMap { log in
            guard let ppm = log.primarySanitizerPpm else { return nil }
            let day = cal.startOfDay(for: log.loggedAt)
            return ChartPoint(id: log.persistentModelID, day: day, value: ppm)
        }
    }

    private var sanitizerYDomain: ClosedRange<Double> {
        if isBromine { return 0 ... 6 }
        return 0 ... 5
    }

    private var userCountByDay: [String: Int] {
        var m: [String: Int] = [:]
        let cal = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        for u in filteredUsageLogs {
            let day = cal.startOfDay(for: u.loggedAt)
            let k = df.string(from: day)
            m[k, default: 0] += u.numUsers
        }
        return m
    }

    private var hasData: Bool {
        !filteredDailyLogs.isEmpty || !filteredUsageLogs.isEmpty
    }

    private var chemicalOn: Bool {
        showSanitizer || showPH
    }

    private var hasVisibleChemicalSeries: Bool {
        (showPH && !phMarks.isEmpty) || (showSanitizer && !sanitizerMarks.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                periodControls
                toggles

                if !chemicalOn && !showUsers {
                    AppEmptyState(
                        symbol: "chart.xyaxis.line",
                        title: "No layers selected",
                        message: "Turn on at least one chart layer to see trends."
                    )
                } else if !hasData {
                    AppEmptyState(
                        symbol: "calendar",
                        title: chartRange == .last7Days ? "No data in this period" : "No data for \(monthLabel)",
                        message: "Add logs to see charts"
                    )
                } else {
                    if chemicalOn {
                        combinedChemicalChart
                    }
                    if showUsers {
                        usersChart
                    }
                }

                if showSanitizer || showPH || showUsers {
                    guideSection
                }
            }
            .appScrollScreenPadding()
        }
        .appGroupedScreenBackground(palette)
        .navigationTitle("Charts")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { HotTubModelContainer.seedIfNeeded(in: modelContext) }
    }

    private var periodControls: some View {
        VStack(spacing: AppSpacing.control) {
            HStack(spacing: 8) {
                ForEach(ChartRange.allCases, id: \.self) { range in
                    rangePill(range)
                }
            }

            if chartRange == .month {
                monthNav
            } else {
                sevenDayNav
            }
        }
    }

    private func rangePill(_ range: ChartRange) -> some View {
        let selected = chartRange == range
        return Button {
            chartRange = range
            if range == .last7Days {
                sevenDayWeekStart = currentWeekMonday
            }
        } label: {
            Text(range.rawValue)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? palette.color(.accentBlue).opacity(0.12) : palette.color(.surfaceCard))
                .foregroundStyle(selected ? palette.color(.accentBlue) : palette.color(.textPrimary))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            selected ? palette.color(.accentBlue) : palette.color(.separator),
                            lineWidth: selected ? 2 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var monthNav: some View {
        let canGoBack = viewMonthStart > (monthPickerOptions.first ?? viewMonthStart)
        let canGoForward = viewMonthStart < (monthPickerOptions.last ?? viewMonthStart)

        return HStack(spacing: 8) {
            Button {
                if let prev = Calendar.current.date(byAdding: .month, value: -1, to: viewMonthStart) {
                    viewMonth = prev
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canGoBack ? palette.color(.accentBlue) : palette.color(.separator))
            }
            .disabled(!canGoBack)

            monthPeriodPicker
                .frame(maxWidth: .infinity)

            Button {
                if let next = Calendar.current.date(byAdding: .month, value: 1, to: viewMonthStart) {
                    viewMonth = next
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canGoForward ? palette.color(.accentBlue) : palette.color(.separator))
            }
            .disabled(!canGoForward)
        }
        .padding(.vertical, 4)
    }

    private var monthPeriodPicker: some View {
        Picker(
            "Month",
            selection: Binding(
                get: { viewMonthStart },
                set: { viewMonth = $0 }
            )
        ) {
            ForEach(monthPickerOptions, id: \.self) { monthStart in
                Text(monthPickerLabel(for: monthStart)).tag(monthStart)
            }
        }
        .pickerStyle(.menu)
        .tint(palette.color(.accentBlue))
    }

    private var sevenDayNav: some View {
        HStack(spacing: 8) {
            Button {
                shiftSevenDayWindow(by: -7)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(palette.color(.accentBlue))
            }

            weekPeriodPicker
                .frame(maxWidth: .infinity)

            Button {
                shiftSevenDayWindow(by: 7)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canAdvanceSevenDayWindow ? palette.color(.accentBlue) : palette.color(.separator))
            }
            .disabled(!canAdvanceSevenDayWindow)
        }
        .padding(.vertical, 4)
    }

    private var weekPeriodPicker: some View {
        Picker("Week", selection: $sevenDayWeekStart) {
            ForEach(weekPickerOptions, id: \.self) { monday in
                Text(weekPickerLabel(for: monday)).tag(monday)
            }
        }
        .pickerStyle(.menu)
        .tint(palette.color(.accentBlue))
    }

    private func monthPickerLabel(for monthStart: Date) -> String {
        let formatter = DateFormatter()
        let cal = Calendar.current
        if cal.component(.year, from: monthStart) == cal.component(.year, from: todayStart) {
            formatter.dateFormat = "MMMM"
        } else {
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: monthStart)
    }

    private func weekPickerLabel(for weekStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "Week of \(formatter.string(from: weekStart))"
    }

    private func shiftSevenDayWindow(by days: Int) {
        let cal = Calendar.current
        guard let shifted = cal.date(byAdding: .day, value: days, to: sevenDayWeekStart) else { return }
        if days > 0 {
            sevenDayWeekStart = min(shifted, currentWeekMonday)
        } else {
            sevenDayWeekStart = shifted
        }
    }

    private var toggles: some View {
        HStack(spacing: 10) {
            togglePill(isBromine ? "BR" : "CL", on: $showSanitizer, color: palette.color(.accentBlue))
            togglePill("pH", on: $showPH, color: palette.color(.accentGreen))
            togglePill("Users", on: $showUsers, color: palette.color(.accentOrange))
        }
    }

    private func togglePill(_ title: String, on: Binding<Bool>, color: Color) -> some View {
        Button {
            on.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on.wrappedValue ? color : palette.color(.separator))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.color(.surfaceCard))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on.wrappedValue ? color : palette.color(.separator), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.color(.textPrimary))
    }

    private var combinedChemicalChart: some View {
        chartCard(title: "Water chemistry") {
            if !hasVisibleChemicalSeries {
                Text(emptyChemicalMessage)
                    .font(.caption)
                    .foregroundStyle(palette.color(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 200)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.control) {
                    chemicalLegend
                    dualAxisChemicalChart
                        .frame(height: 240)
                }
            }
        }
    }

    private var emptyChemicalMessage: String {
        let window = chartRange == .last7Days ? last7DaysLabel : "this month"
        if showPH && showSanitizer {
            return "No pH or \(sanitizerLabel.lowercased()) readings in \(window)."
        }
        if showPH {
            return "No pH readings in \(window)."
        }
        return "No \(sanitizerLabel.lowercased()) readings in \(window)."
    }

    private var chemicalLegend: some View {
        HStack(spacing: 16) {
            if showPH {
                legendItem(color: palette.color(.accentGreen), label: "pH", axis: "left")
            }
            if showSanitizer {
                legendItem(
                    color: palette.color(.accentBlue),
                    label: "\(sanitizerLabel) (ppm)",
                    axis: "right"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(palette.color(.textSecondary))
    }

    private func legendItem(color: Color, label: String, axis: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
            Text("·")
            Text(axis)
                .foregroundStyle(palette.color(.textTertiary))
        }
    }

    private var dualAxisChemicalChart: some View {
        ZStack {
            if showSanitizer, !sanitizerMarks.isEmpty {
                Chart {
                    ForEach(sanitizerMarks) { mark in
                        LineMark(
                            x: .value("Day", mark.day, unit: .day),
                            y: .value("ppm", mark.value)
                        )
                        .foregroundStyle(palette.color(.accentBlue))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", mark.day, unit: .day),
                            y: .value("ppm", mark.value)
                        )
                        .foregroundStyle(palette.color(.accentBlue))
                        .symbolSize(36)
                    }
                }
                .chartYScale(domain: sanitizerYDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(palette.color(.separator).opacity(0.5))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    dayXAxisMarks(showLabels: true, showGrid: true)
                }
                .chartXScale(domain: chartXDomain)
            }

            if showPH, !phMarks.isEmpty {
                Chart {
                    ForEach(phMarks) { mark in
                        LineMark(
                            x: .value("Day", mark.day, unit: .day),
                            y: .value("pH", mark.value)
                        )
                        .foregroundStyle(palette.color(.accentGreen))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", mark.day, unit: .day),
                            y: .value("pH", mark.value)
                        )
                        .foregroundStyle(palette.color(.accentGreen))
                        .symbolSize(36)
                    }
                }
                .chartYScale(domain: 6.8 ... 8.2)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    let sanitizerChartVisible = showSanitizer && !sanitizerMarks.isEmpty
                    dayXAxisMarks(
                        showLabels: !sanitizerChartVisible,
                        showGrid: !sanitizerChartVisible
                    )
                }
                .chartXScale(domain: chartXDomain)
            }
        }
    }

    @AxisContentBuilder
    private func dayXAxisMarks(showLabels: Bool, showGrid: Bool) -> some AxisContent {
        AxisMarks(values: xAxisMarkDates) { _ in
            if showGrid {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(palette.color(.separator).opacity(0.5))
            }
            if showLabels {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
    }

    private var usersChart: some View {
        let barPoints: [UserBarPoint] = userCountByDay.keys.sorted().compactMap { k in
            guard let d = parseYMD(k), let n = userCountByDay[k] else { return nil }
            return UserBarPoint(id: k, day: d, count: n)
        }
        return chartCard(title: "Users per day") {
            if barPoints.isEmpty {
                Text(
                    chartRange == .last7Days
                        ? "No usage logs from \(last7DaysLabel)"
                        : "No usage logs this month"
                )
                    .font(.caption)
                    .foregroundStyle(palette.color(.textSecondary))
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(barPoints) { p in
                        BarMark(
                            x: .value("Day", p.day, unit: .day),
                            y: .value("Users", p.count)
                        )
                        .foregroundStyle(palette.color(.accentOrange).opacity(0.85))
                    }
                }
                .chartXAxis {
                    dayXAxisMarks(showLabels: true, showGrid: true)
                }
                .chartXScale(domain: chartXDomain)
                .frame(height: 220)
            }
        }
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            if showSanitizer {
                chartsGuideCard(
                    title: "\(sanitizerLabel) Guide",
                    symbol: "drop.fill",
                    color: palette.color(.accentBlue),
                    bullets: sanitizerGuideBullets
                )
            }
            if showPH {
                chartsGuideCard(
                    title: "pH Guide",
                    symbol: "testtube.2",
                    color: palette.color(.accentGreen),
                    bullets: phGuideBullets
                )
            }
            if showUsers {
                chartsGuideCard(
                    title: "Usage Guide",
                    symbol: "person.2.fill",
                    color: palette.color(.accentOrange),
                    bullets: usageGuideBullets
                )
            }
        }
    }

    private var sanitizerGuideBullets: [String] {
        if isBromine {
            return [
                "Ideal Bromine: 3.0 - 5.0 ppm",
                "Bromine is the active sanitizer in your water.",
                "If levels are low, add bromine immediately.",
                "If levels are high, wait for them to drop before using.",
            ]
        }
        return [
            "Ideal Free Chlorine: 1.0 - 3.0 ppm",
            "Free Chlorine is the active sanitizer in your water.",
            "If levels are low, add chlorine immediately.",
            "If levels are high, wait for them to drop before using.",
        ]
    }

    private var phGuideBullets: [String] {
        [
            "Ideal pH: 7.2 - 7.8",
            "pH affects sanitizer effectiveness and water comfort.",
            "Too low (acidic): Add pH Up to raise levels.",
            "Too high (basic): Add pH Down to lower levels.",
        ]
    }

    private var usageGuideBullets: [String] {
        [
            "Track how many people use your hot tub daily.",
            "Higher usage may require more frequent chemical adjustments.",
            "Test water quality after heavy use sessions.",
        ]
    }

    private func chartsGuideCard(
        title: String,
        symbol: String,
        color: Color,
        bullets: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.color(.textPrimary))
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(color)
                        Text(bullet)
                            .font(.caption)
                            .foregroundStyle(palette.color(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .appCard(palette: palette)
    }

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.color(.textPrimary))
            content()
        }
        .appCard(palette: palette, radius: AppSpacing.largeCardRadius)
    }

    private func parseYMD(_ ymd: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)
    }
}

// MARK: - Calendar week helpers

private enum ChartsWeekCalendar {
    static func mondayContaining(_ date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.startOfDay(for: date)
        while cal.component(.weekday, from: day) != 2 {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return day
    }

    static func weekEnd(forWeekStarting monday: Date, cappedTo today: Date) -> Date {
        let cal = Calendar.current
        let sunday = cal.date(byAdding: .day, value: 6, to: cal.startOfDay(for: monday)) ?? monday
        return min(cal.startOfDay(for: sunday), today)
    }
}
