//
//  ChartsScreenView.swift
//  HotTub
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

private struct ChemistryPeriodSummary {
    let testsRecorded: Int
    let phReadingCount: Int
    let phInRangePercent: Int?
    let sanitizerReadingCount: Int
    let sanitizerLowCount: Int
}

private enum ChartRange: String, CaseIterable {
    case last7Days = "Week"
    case month = "Month"
    case threeMonths = "3 months"
}

struct ChartsScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \HotTubDailyLog.loggedAt, order: .forward) private var allDaily: [HotTubDailyLog]
    @Query(sort: \UsageLogEntry.loggedAt, order: .forward) private var allUsage: [UsageLogEntry]
    @Query private var settingsRows: [AppSettings]

    @State private var chartRange: ChartRange = .month
    @State private var viewMonth: Date = Date()
    /// Monday starting the visible calendar week (7-day window ends that Sunday or today).
    @State private var sevenDayWeekStart: Date = ChartsWeekCalendar.mondayContaining(Date())
    @State private var presentedHelp: HelpSheetRequest?

    private var isBromine: Bool {
        settingsRows.first?.isBromine ?? false
    }

    private var isMetric: Bool {
        settingsRows.first?.measurementSystem != "imperial"
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

    private var availableChartRanges: [ChartRange] {
        horizontalSizeClass == .regular ? ChartRange.allCases : [.last7Days, .month]
    }

    private var threeMonthsStart: Date {
        let cal = Calendar.current
        let anchor = cal.date(from: cal.dateComponents([.year, .month], from: todayStart)) ?? todayStart
        return cal.date(byAdding: .month, value: -2, to: anchor) ?? anchor
    }

    private var threeMonthsEnd: Date {
        todayStart
    }

    private var threeMonthsLabel: String {
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "d MMM"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "d MMM yyyy"
        return "\(startFormatter.string(from: threeMonthsStart)) – \(endFormatter.string(from: threeMonthsEnd))"
    }

    private var emptyStatePeriodTitle: String {
        switch chartRange {
        case .last7Days:
            return "No data in this period"
        case .month:
            return "No data for \(monthLabel)"
        case .threeMonths:
            return "No data in the last 3 months"
        }
    }

    private var noDataPeriodPhrase: String {
        switch chartRange {
        case .last7Days:
            return last7DaysLabel
        case .month:
            return "this month"
        case .threeMonths:
            return "the last 3 months"
        }
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
        case .threeMonths:
            return day >= threeMonthsStart && day <= threeMonthsEnd
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
        case .threeMonths:
            return threeMonthsStart ... threeMonthsEnd
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

    /// First of each month in the rolling 3-month window.
    private var threeMonthMarkDates: [Date] {
        let cal = Calendar.current
        var dates: [Date] = []
        var month = threeMonthsStart
        while month <= threeMonthsEnd {
            dates.append(month)
            guard let next = cal.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return dates
    }

    private var xAxisMarkDates: [Date] {
        switch chartRange {
        case .month:
            return monthMondayMarkDates
        case .last7Days:
            return sevenDayMarkDates
        case .threeMonths:
            return threeMonthMarkDates
        }
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

    private var hasVisibleChemicalSeries: Bool {
        !phMarks.isEmpty || !sanitizerMarks.isEmpty
    }

    private var chemistryPeriodSummary: ChemistryPeriodSummary? {
        let logs = filteredDailyLogs
        guard !logs.isEmpty else { return nil }

        let phValues = logs.compactMap(\.ph)
        let phInRangePercent: Int? = phValues.isEmpty
            ? nil
            : Int((Double(phValues.filter { WaterChemistryRanges.phIdeal.contains($0) }.count)
                / Double(phValues.count) * 100).rounded())

        let idealMin = isBromine
            ? WaterChemistryRanges.bromineIdeal.lowerBound
            : WaterChemistryRanges.chlorineIdeal.lowerBound
        let sanitizerValues = logs.compactMap(\.primarySanitizerPpm)
        let sanitizerLowCount = sanitizerValues.filter { $0 < idealMin }.count

        return ChemistryPeriodSummary(
            testsRecorded: logs.count,
            phReadingCount: phValues.count,
            phInRangePercent: phInRangePercent,
            sanitizerReadingCount: sanitizerValues.count,
            sanitizerLowCount: sanitizerLowCount
        )
    }

    private var summaryPeriodPhrase: String {
        switch chartRange {
        case .month:
            return "this month"
        case .last7Days:
            return "this week"
        case .threeMonths:
            return "in the last 3 months"
        }
    }

    private var showsChemistrySummary: Bool {
        guard let summary = chemistryPeriodSummary else { return false }
        return summary.testsRecorded > 0
            && (summary.phReadingCount > 0 || summary.sanitizerReadingCount > 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                periodControls

                if hasData, showsChemistrySummary, let summary = chemistryPeriodSummary {
                    chemistrySummarySection(summary)
                }

                if !hasData {
                    AppEmptyState(
                        symbol: "calendar",
                        title: emptyStatePeriodTitle,
                        message: "Add logs to see charts"
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.control) {
                        sanitizerCompactChart
                        phCompactChart
                        if hasVisibleChemicalSeries {
                            chemistryStatusLegend
                        }
                    }
                    usersChart
                }

                guideSection
            }
            .appScrollScreenPadding()
        }
        .appGroupedScreenBackground(palette)
        .navigationTitle("Charts")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            HotTubModelContainer.seedIfNeeded(in: modelContext)
            clampChartRangeIfNeeded()
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            clampChartRangeIfNeeded()
        }
        .helpSheet(presentedHelp: $presentedHelp, isBromine: isBromine, isMetric: isMetric)
    }

    private func clampChartRangeIfNeeded() {
        if !availableChartRanges.contains(chartRange) {
            chartRange = .month
        }
    }

    private func chemistrySummarySection(_ summary: ChemistryPeriodSummary) -> some View {
        VStack(spacing: AppSpacing.control) {
            HStack(alignment: .top, spacing: AppSpacing.control) {
                if summary.phReadingCount > 0, let percent = summary.phInRangePercent {
                    phSummaryCard(percent: percent)
                }
                if summary.sanitizerReadingCount > 0 {
                    sanitizerSummaryCard(lowCount: summary.sanitizerLowCount)
                }
            }

            if summary.phReadingCount > 0 {
                chemistryTipBanner
            }
        }
    }

    private func phSummaryCard(percent: Int) -> some View {
        VStack(spacing: 12) {
            ChartsSummaryRing(
                progress: Double(percent) / 100,
                color: palette.color(.accentGreen),
                trackColor: palette.color(.accentGreen).opacity(0.2),
                label: "\(percent)%"
            )

            Text("pH in range")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.color(.textPrimary))

            Text("\(percent)% of readings in range \(summaryPeriodPhrase).")
                .font(.caption)
                .foregroundStyle(palette.color(.textSecondary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .appCard(palette: palette, radius: AppSpacing.cardRadius, padding: 16)
    }

    private func sanitizerSummaryCard(lowCount: Int) -> some View {
        let inRange = lowCount == 0
        return VStack(spacing: 12) {
            if inRange {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(palette.color(.accentGreen))
                    .frame(height: 72)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(palette.color(.accentOrange))
                    Text("\(lowCount)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(palette.color(.textPrimary))
                }
                .frame(height: 72)
            }

            Text(inRange ? "\(sanitizerLabel) in range" : "Low \(sanitizerLabel.lowercased())")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.color(.textPrimary))

            Text(
                inRange
                    ? "All readings in range \(summaryPeriodPhrase)."
                    : "\(lowCount) time\(lowCount == 1 ? "" : "s") \(summaryPeriodPhrase) below recommended range."
            )
            .font(.caption)
            .foregroundStyle(palette.color(.textSecondary))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .appCard(palette: palette, radius: AppSpacing.cardRadius, padding: 16)
    }

    private var chemistryTipBanner: some View {
        Button {
            presentedHelp = .ph(.overview)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.color(.accentBlue))
                    .frame(width: 24)

                Text(tipBannerText)
                    .font(.caption)
                    .foregroundStyle(palette.color(.textPrimary))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.color(.textTertiary))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(palette.color(.tagBlueFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var tipBannerText: AttributedString {
        var tip = AttributedString("Tip ")
        tip.font = .caption.weight(.semibold)
        var body = AttributedString("Keep pH between 7.2 and 7.8 for best sanitizer effectiveness.")
        body.font = .caption
        return tip + body
    }

    private var periodControls: some View {
        VStack(spacing: AppSpacing.control) {
            HStack(spacing: 8) {
                ForEach(availableChartRanges, id: \.self) { range in
                    rangePill(range)
                }
            }

            switch chartRange {
            case .month:
                monthNav
            case .last7Days:
                sevenDayNav
            case .threeMonths:
                threeMonthsPeriodLabel
            }
        }
    }

    private var threeMonthsPeriodLabel: some View {
        Text(threeMonthsLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.color(.textPrimary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
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

    private var sanitizerCompactChart: some View {
        let ideal = isBromine ? WaterChemistryRanges.bromineIdeal : WaterChemistryRanges.chlorineIdeal
        let subtitle = isBromine ? "Target 3.0–5.0 ppm" : "Target 1.0–3.0 ppm"
        return compactChemistryChart(
            title: sanitizerLabel,
            subtitle: subtitle,
            marks: sanitizerMarks,
            idealRange: ideal,
            yDomain: sanitizerYDomain,
            yAxisFormat: { String(format: "%.0f", $0) },
            status: sanitizerReadingStatus(for:),
            emptyMessage: "No \(sanitizerLabel.lowercased()) readings in \(noDataPeriodPhrase)."
        )
    }

    private func sanitizerReadingStatus(for value: Double) -> WaterChemistryReadingStatus {
        if isBromine {
            WaterChemistryRanges.bromineStatus(value)
        } else {
            WaterChemistryRanges.chlorineStatus(value)
        }
    }

    private var phCompactChart: some View {
        compactChemistryChart(
            title: "pH",
            subtitle: "Target 7.2–7.8",
            marks: phMarks,
            idealRange: WaterChemistryRanges.phIdeal,
            yDomain: 6.8 ... 8.2,
            yAxisFormat: { String(format: "%.1f", $0) },
            status: WaterChemistryRanges.phStatus,
            emptyMessage: "No pH readings in \(noDataPeriodPhrase)."
        )
    }

    private var chemistryStatusLegend: some View {
        HStack(spacing: 16) {
            statusLegendItem(color: palette.color(.accentGreen), label: "In range")
            statusLegendItem(color: palette.color(.accentOrange), label: "Slightly outside")
            statusLegendItem(color: palette.color(.accentRed), label: "Needs attention")
        }
        .font(.caption)
        .foregroundStyle(palette.color(.textSecondary))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func compactChemistryChart(
        title: String,
        subtitle: String,
        marks: [ChartPoint],
        idealRange: ClosedRange<Double>,
        yDomain: ClosedRange<Double>,
        yAxisFormat: @escaping (Double) -> String,
        status: @escaping (Double) -> WaterChemistryReadingStatus,
        emptyMessage: String
    ) -> some View {
        chartCard(title: title) {
            if marks.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(palette.color(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 120)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.color(.textSecondary))

                    Chart {
                        RectangleMark(
                            xStart: .value("Start", chartXDomain.lowerBound, unit: .day),
                            xEnd: .value("End", chartXDomain.upperBound, unit: .day),
                            yStart: .value("Ideal low", idealRange.lowerBound),
                            yEnd: .value("Ideal high", idealRange.upperBound)
                        )
                        .foregroundStyle(palette.color(.statusSuccessFill))

                        ForEach(marks) { mark in
                            LineMark(
                                x: .value("Day", mark.day, unit: .day),
                                y: .value(title, mark.value)
                            )
                            .foregroundStyle(palette.color(.separator).opacity(0.6))
                            .interpolationMethod(.catmullRom)
                        }

                        ForEach(marks) { mark in
                            PointMark(
                                x: .value("Day", mark.day, unit: .day),
                                y: .value(title, mark.value)
                            )
                            .foregroundStyle(
                                WaterChemistryRanges.statusColor(status(mark.value), palette: palette)
                            )
                            .symbolSize(44)
                        }
                    }
                    .chartYScale(domain: yDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                .foregroundStyle(palette.color(.separator).opacity(0.4))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(yAxisFormat(v))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        chartXAxisMarks(showLabels: true, showGrid: true)
                    }
                    .chartXScale(domain: chartXDomain)
                    .frame(height: 150)
                }
            }
        }
    }

    @AxisContentBuilder
    private func chartXAxisMarks(showLabels: Bool, showGrid: Bool) -> some AxisContent {
        AxisMarks(values: xAxisMarkDates) { _ in
            if showGrid {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(palette.color(.separator).opacity(0.5))
            }
            if showLabels {
                if chartRange == .threeMonths {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                } else {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
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
                Text("No usage logs from \(noDataPeriodPhrase)")
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
                    chartXAxisMarks(showLabels: true, showGrid: true)
                }
                .chartXScale(domain: chartXDomain)
                .frame(height: 220)
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

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            chartsGuideCard(
                title: "\(sanitizerLabel) Guide",
                symbol: "drop.fill",
                color: palette.color(.accentBlue),
                bullets: sanitizerGuideBullets
            )
            chartsGuideCard(
                title: "pH Guide",
                symbol: "testtube.2",
                color: palette.color(.accentGreen),
                bullets: phGuideBullets
            )
            chartsGuideCard(
                title: "Usage Guide",
                symbol: "person.2.fill",
                color: palette.color(.accentOrange),
                bullets: usageGuideBullets
            )
        }
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

// MARK: - Summary ring

private struct ChartsSummaryRing: View {
    let progress: Double
    let color: Color
    let trackColor: Color
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(width: 72, height: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
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
