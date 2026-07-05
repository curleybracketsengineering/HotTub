//
//  DashboardView.swift
//  HotTub
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.openURL) private var openURL
    @ObservedObject private var notificationService = ReminderNotificationService.shared
    @StateObject private var viewModel = DashboardViewModel()

    @State private var showNotificationSettings = false
    @State private var showNotificationsDeniedAlert = false
    @State private var navigateToDailyLog = false
    @State private var navigateToWeeklyCheck = false
    @State private var navigateToMaintenancePreset: MaintenanceLogPreset?

    var body: some View {
        ScrollView {
            Group {
                if usePadLayout {
                    padDashboardContent
                } else {
                    phoneDashboardContent
                }
            }
            .appAdaptiveScrollPadding(usePadLayout: usePadLayout)
            .padReadableContent(maxWidth: usePadLayout ? PadContentLayout.dashboardMaxWidth : PadContentLayout.readableMaxWidth)
        }
        .appGroupedScreenBackground(palette)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: usePadLayout ? .topBarLeading : .topBarTrailing) {
                notificationBellButton
            }
        }
        .task {
            viewModel.reload(context: modelContext)
            guard !PreviewEnvironment.isActive else { return }
            await notificationService.refreshAuthorizationStatus()
            await notificationService.reschedule(context: modelContext)
        }
        .onAppear { viewModel.reload(context: modelContext) }
        .refreshable {
            viewModel.reload(context: modelContext)
            guard !PreviewEnvironment.isActive else { return }
            await notificationService.reschedule(context: modelContext)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsSheet(notificationService: notificationService)
        }
        .alert("Notifications are off", isPresented: $showNotificationsDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Turn on notifications in Settings to get maintenance reminders.")
        }
        .navigationDestination(isPresented: $navigateToDailyLog) {
            DailyLogFormView()
        }
        .navigationDestination(isPresented: $navigateToWeeklyCheck) {
            WeeklyLogFormView()
        }
        .navigationDestination(item: $navigateToMaintenancePreset) { preset in
            MaintenanceLogFormView(preset: preset)
        }
        .onChange(of: notificationService.pendingDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .dailyLog:
                navigateToDailyLog = true
            case .weeklyCheck:
                navigateToWeeklyCheck = true
            case .maintenanceFilterRinse:
                navigateToMaintenancePreset = .filterRinse
            case .maintenanceFilterChange:
                navigateToMaintenancePreset = .filterChange
            case .maintenanceWaterChange:
                navigateToMaintenancePreset = .waterChange
            }
            notificationService.pendingDestination = nil
        }
    }

    private var phoneDashboardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            statusCard
            actionsSection
            recentRecordsSection
            remindersSection
        }
    }

    private var padDashboardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            padStatusBanner
            padMainActionButton
            padSecondaryActions

            HStack(alignment: .top, spacing: AppSpacing.section) {
                padRecentRecordsColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                padRemindersColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            padFooter
        }
    }

    // MARK: - iPad hero banner

    private var padStatusBanner: some View {
        let log = viewModel.latestDailyLog
        let hasData = log != nil
        let isStale = viewModel.readingsAreStale
        let isDailyDue = log == nil || isStale
        let inRange = isWithinTypicalRange(log)
        let sanitizerIdeal = viewModel.isBromine
            ? WaterChemistryRanges.bromineIdeal
            : WaterChemistryRanges.chlorineIdeal
        let sanitizerDisplayRange = viewModel.isBromine
            ? WaterChemistryRanges.bromineDisplay
            : WaterChemistryRanges.chlorineDisplay

        return ZStack {
            statusCardGradient(
                hasData: hasData,
                isStale: isStale || isDailyDue,
                inRange: inRange
            )

            PadHeroWaveDecoration()
                .opacity(0.18)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundStyle(palette.color(.accentBlue))
                            .frame(width: 48, height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                viewModel.heroHeadline(
                                    ph: log?.ph,
                                    sanitizer: log?.primarySanitizerPpm,
                                    hasData: hasData,
                                    isDailyDue: isDailyDue
                                )
                            )
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.color(.onAccent))

                            if let log {
                                Text("Last water test \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))")
                                    .font(.subheadline)
                                    .foregroundStyle(palette.color(.onAccent).opacity(0.8))
                            } else {
                                Text("No readings logged yet")
                                    .font(.subheadline)
                                    .foregroundStyle(palette.color(.onAccent).opacity(0.8))
                            }
                        }
                    }

                    if isDailyDue {
                        NavigationLink {
                            DailyLogFormView()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption.weight(.semibold))
                                Text("Due today")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(palette.color(.accentBlue))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if hasData {
                        padHeroStatusBadge(inRange: inRange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 16)

                padHeroDivider

                padHeroReadingColumn(
                    label: viewModel.isBromine ? "Bromine" : "Chlorine",
                    value: log?.primarySanitizerPpm,
                    valueText: sanitizerDisplay(log),
                    targetLabel: sanitizerTargetLabel,
                    idealRange: sanitizerIdeal,
                    displayRange: sanitizerDisplayRange,
                    status: log?.primarySanitizerPpm.map {
                        viewModel.isBromine
                            ? WaterChemistryRanges.bromineStatus($0)
                            : WaterChemistryRanges.chlorineStatus($0)
                    }
                )
                .padding(.horizontal, 16)

                padHeroDivider

                padHeroReadingColumn(
                    label: "pH",
                    value: log?.ph,
                    valueText: log?.ph.map { String(format: "%.1f", $0) } ?? "--",
                    targetLabel: "Target: 7.2 – 7.8",
                    idealRange: WaterChemistryRanges.phIdeal,
                    displayRange: WaterChemistryRanges.phDisplay,
                    status: log?.ph.map(WaterChemistryRanges.phStatus)
                )
                .padding(.leading, 16)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.largeCardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var padHeroDivider: some View {
        Rectangle()
            .fill(palette.color(.onAccent).opacity(0.22))
            .frame(width: 1)
            .frame(maxHeight: 88)
    }

    @ViewBuilder
    private func padHeroStatusBadge(inRange: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: inRange ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption)
            Text(inRange ? "Last result was within range" : "Some readings outside range")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(palette.color(.onAccent))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(inRange ? 0.2 : 0.16))
        .clipShape(Capsule())
    }

    private func padHeroReadingColumn(
        label: String,
        value: Double?,
        valueText: String,
        targetLabel: String,
        idealRange: ClosedRange<Double>,
        displayRange: ClosedRange<Double>,
        status: WaterChemistryReadingStatus?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.color(.onAccent).opacity(0.75))

            Text(valueText)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.color(.onAccent))

            Text(targetLabel)
                .font(.caption2)
                .foregroundStyle(palette.color(.onAccent).opacity(0.65))

            ChemistryRangeGauge(
                value: value,
                idealRange: idealRange,
                displayRange: displayRange,
                status: status
            )
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sanitizerTargetLabel: String {
        if viewModel.isBromine {
            return "Target: 3.0 – 5.0 ppm"
        }
        return "Target: 1.0 – 3.0 ppm"
    }

    private var padMainActionButton: some View {
        NavigationLink {
            DailyLogFormView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.title3)
                Text("Record water test")
                    .font(.headline)
            }
            .foregroundStyle(palette.color(.onAccent))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(palette.color(.accentBlue))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var padSecondaryActions: some View {
        HStack(spacing: AppSpacing.control) {
            padActionCard(kind: .usage, destination: UsageLogFormView())
            padActionCard(kind: .weekly, destination: WeeklyLogFormView())
            padActionCard(kind: .maintenance, destination: MaintenanceLogFormView())
        }
    }

    private func padActionCard<D: View>(kind: ActivityLogKind, destination: D) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.tileSystemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.color(kind.iconToken))
                    .frame(width: 44, height: 44)
                    .background(palette.color(kind.fillToken))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.padActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.color(.textPrimary))
                    Text(kind.padActionSubtitle)
                        .font(.caption)
                        .foregroundStyle(palette.color(.textSecondary))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.color(.textTertiary))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard(palette: palette, radius: AppSpacing.largeCardRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - iPad columns

    private var padRecentRecordsColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent records")
                    .font(.headline)
                    .foregroundStyle(palette.color(.textPrimary))
                Spacer()
                NavigationLink("View all records") {
                    HistoryView(isTabRoot: false)
                }
                .font(.subheadline.weight(.medium))
            }

            if viewModel.recentRecords.isEmpty {
                AppEmptyState(
                    symbol: "clock.arrow.circlepath",
                    title: "No records yet",
                    message: "Log a daily reading or weekly check to see it here."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentRecords.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            AppSettingsDivider()
                        }
                        padCompactActivityLink(item)
                    }
                }
                .appCard(palette: palette, padding: 0)

                NavigationLink {
                    HistoryView(isTabRoot: false)
                } label: {
                    Text("View all records")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.color(.accentBlue))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func padCompactActivityLink(_ item: DashboardActivity) -> some View {
        NavigationLink {
            activityDetail(item)
        } label: {
            ActivityRowView(row: item.historyRow, isBromine: viewModel.isBromine, palette: palette)
                .padding(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.delete(item, context: modelContext)
                Task { await notificationService.reschedule(context: modelContext) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var padRemindersColumn: some View {
        remindersCard
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reminders")
                    .font(.headline)
                    .foregroundStyle(palette.color(.textPrimary))
                Spacer()
                NavigationLink {
                    SetupView()
                } label: {
                    Text("Manage")
                        .font(.subheadline.weight(.medium))
                }
            }

            if viewModel.dueReminders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(palette.color(.accentGreen))
                    Text("All caught up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.color(.textPrimary))
                    Text("No maintenance tasks due in the next two weeks.")
                        .font(.caption)
                        .foregroundStyle(palette.color(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(palette: palette)
            } else {
                VStack(spacing: AppSpacing.control) {
                    ForEach(viewModel.dueReminders) { reminder in
                        reminderCard(reminder)
                    }
                }
            }
        }
    }

    private func reminderCard(_ reminder: HomeReminder) -> some View {
        let urgency = reminder.urgency()
        let colors = reminderColors(for: urgency)

        return NavigationLink {
            reminderDestination(reminder.kind)
        } label: {
            HStack(spacing: AppSpacing.control) {
                Image(systemName: reminder.kind.systemImage(urgency: urgency))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(colors.icon)
                    .frame(width: 40, height: 40)
                    .background(colors.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.color(.textPrimary))
                    Text(reminder.padSubtitle())
                        .font(.caption)
                        .foregroundStyle(palette.color(.textSecondary))
                }

                Spacer(minLength: 8)

                Text(reminder.badgeLabel())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(colors.badgeText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.badgeBackground)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.color(.textTertiary))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(colors.background)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(colors.border.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private struct ReminderCardColors {
        let background: Color
        let border: Color
        let icon: Color
        let iconBackground: Color
        let badgeBackground: Color
        let badgeText: Color
    }

    private func reminderColors(for urgency: HomeReminder.Urgency) -> ReminderCardColors {
        switch urgency {
        case .overdue:
            return ReminderCardColors(
                background: palette.color(.statusErrorFill),
                border: palette.color(.statusErrorBorder),
                icon: palette.color(.accentRed),
                iconBackground: palette.color(.statusErrorFill),
                badgeBackground: palette.color(.accentRed).opacity(0.16),
                badgeText: palette.color(.statusErrorText)
            )
        case .dueToday:
            return ReminderCardColors(
                background: palette.color(.statusWarningFill),
                border: palette.color(.statusWarningBorder),
                icon: palette.color(.accentOrange),
                iconBackground: palette.color(.statusWarningFill),
                badgeBackground: palette.color(.accentOrange).opacity(0.16),
                badgeText: palette.color(.statusWarningText)
            )
        case .upcoming:
            return ReminderCardColors(
                background: palette.color(.accentBlue).opacity(0.08),
                border: palette.color(.accentBlue).opacity(0.25),
                icon: palette.color(.accentBlue),
                iconBackground: palette.color(.accentBlue).opacity(0.12),
                badgeBackground: palette.color(.accentBlue).opacity(0.12),
                badgeText: palette.color(.accentBlue)
            )
        }
    }

    private var padFooter: some View {
        HStack(alignment: .top) {
            Text("Keep your water balanced for a safe and enjoyable soak.")
                .font(.caption)
                .foregroundStyle(palette.color(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)

            PadFooterInfoLink(palette: palette)
        }
    }

    private func isWithinTypicalRange(_ log: HotTubDailyLog?) -> Bool {
        guard let log else { return false }
        return !viewModel.phOutOfRange(log.ph) && !viewModel.sanitizerOutOfRange(log.primarySanitizerPpm)
    }

    private var statusCard: some View {
        let log = viewModel.latestDailyLog
        let hasData = log != nil
        let isStale = viewModel.readingsAreStale
        let inRange = isWithinTypicalRange(log)
        let gradient = statusCardGradient(hasData: hasData, isStale: isStale, inRange: inRange)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(palette.color(.onAccent))
                    .padding(10)
                    .background(Color.white.opacity(isStale ? 0.15 : 0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                if hasData, !isStale, let log {
                    Text("Last water test: \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.color(.onAccent))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if isStale {
                staleStatusContent(log: log)
            } else {
                freshStatusContent(log: log, hasData: hasData)
            }
        }
        .padding(20)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.largeCardRadius, style: .continuous))
        .shadow(color: .black.opacity(isStale ? 0.04 : 0.06), radius: 8, y: 4)
        .animation(.spring(response: 0.35), value: isStale)
    }

    private func statusCardGradient(hasData: Bool, isStale: Bool, inRange: Bool = true) -> LinearGradient {
        let colors: [Color]
        if !hasData {
            colors = [palette.color(.heroEmptyStart), palette.color(.heroEmptyEnd)]
        } else if isStale {
            colors = [
                palette.color(.heroEmptyStart),
                palette.color(.heroEmptyEnd).opacity(0.88),
            ]
        } else if inRange {
            colors = [
                palette.color(.accentBlue),
                palette.color(.accentIndigo).opacity(0.92),
            ]
        } else {
            colors = [
                palette.color(.accentIndigo),
                palette.color(.accentBlue).opacity(0.88),
            ]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func freshStatusContent(log: HotTubDailyLog?, hasData: Bool) -> some View {
        Text(hasData ? "Water status" : "Your hot tub")
            .font(.body)
            .foregroundStyle(palette.color(.onAccent).opacity(0.85))

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(
                log.map {
                    viewModel.heroHeadline(
                        ph: $0.ph,
                        sanitizer: $0.primarySanitizerPpm,
                        hasData: true,
                        isDailyDue: false
                    )
                } ?? "Ready to start?"
            )
            .font(.system(size: 28, weight: .heavy))
            .foregroundStyle(palette.color(.onAccent))
            .lineLimit(2)
            .minimumScaleFactor(0.7)

            if hasData {
                AppInfoButton(
                    message: "Typical ranges are for reference only. Test your water and follow product labels before adding chemicals.",
                    accessibilityLabel: "About typical ranges",
                    foreground: palette.color(.onAccent).opacity(0.75)
                )
            }

            Spacer(minLength: 0)
        }

        readingsRow(log: log)
    }

    @ViewBuilder
    private func staleStatusContent(log: HotTubDailyLog?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check water today")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(palette.color(.onAccent))

            if let log {
                Text("Last water test \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.color(.onAccent).opacity(0.75))
            }
        }

        readingsRow(log: log)
            .opacity(0.72)
    }

    @ViewBuilder
    private func readingsRow(log: HotTubDailyLog?) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isBromine ? "Bromine" : "Chlorine")
                    .font(.caption)
                    .foregroundStyle(palette.color(.onAccent).opacity(0.65))
                HStack(spacing: 6) {
                    Text(sanitizerDisplay(log))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.color(.onAccent))
                    if let log, viewModel.sanitizerOutOfRange(log.primarySanitizerPpm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(palette.color(.accentYellow))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(palette.color(.onAccent).opacity(0.25))
                .frame(width: 1, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("pH")
                    .font(.caption)
                    .foregroundStyle(palette.color(.onAccent).opacity(0.65))
                HStack(spacing: 6) {
                    Text(log?.ph.map { String(format: "%.1f", $0) } ?? "--")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.color(.onAccent))
                    if let log, viewModel.phOutOfRange(log.ph) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(palette.color(.accentYellow))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
    }

    private func sanitizerDisplay(_ log: HotTubDailyLog?) -> String {
        guard let ppm = log?.primarySanitizerPpm else { return "-- ppm" }
        return String(format: "%.1f ppm", ppm)
    }

    private var actionsSection: some View {
        VStack(spacing: AppSpacing.control) {
            mainActionButton
            subActionRow
        }
    }

    private var mainActionButton: some View {
        NavigationLink {
            DailyLogFormView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Record water test")
                    .font(.headline)
            }
            .foregroundStyle(palette.color(.onAccent))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(palette.color(.accentBlue))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var subActionRow: some View {
        HStack(spacing: AppSpacing.control) {
           

            NavigationLink {
                UsageLogFormView()
            } label: {
                subActionTile(
                    title: "Log hot-tub usage",
                    systemImage: ActivityLogKind.usage.systemImage,
                    fillToken: ActivityLogKind.usage.fillToken,
                    iconToken: ActivityLogKind.usage.iconToken
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WeeklyLogFormView()
            } label: {
                subActionTile(
                    title: "Full water check",
                    systemImage: ActivityLogKind.weekly.systemImage,
                    fillToken: ActivityLogKind.weekly.fillToken,
                    iconToken: ActivityLogKind.weekly.iconToken
                )
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                MaintenanceLogFormView()
            } label: {
                subActionTile(
                    title: "Record maintenance",
                    systemImage: ActivityLogKind.maintenance.systemImage,
                    fillToken: ActivityLogKind.maintenance.fillToken,
                    iconToken: ActivityLogKind.maintenance.iconToken
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func subActionTile(
        title: String,
        systemImage: String,
        fillToken: PaletteToken,
        iconToken: PaletteToken
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(palette.color(iconToken))
                .frame(width: AppSpacing.minTap, height: AppSpacing.minTap)
                .background(palette.color(fillToken))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.color(.textPrimary))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .appCard(palette: palette, radius: AppSpacing.largeCardRadius)
    }

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            HStack(alignment: .firstTextBaseline) {
                AppSectionHeader(title: "Recent records")
                Spacer()
                NavigationLink("View all records") {
                    HistoryView(isTabRoot: false)
                }
                .font(.subheadline.weight(.medium))
            }

            if viewModel.recentRecords.isEmpty {
                AppEmptyState(
                    symbol: "clock.arrow.circlepath",
                    title: "No records yet",
                    message: "Log a daily reading or weekly check to see it here."
                )
            } else {
                ForEach(viewModel.recentRecords) { item in
                    activityRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        remindersCard
    }

    @ViewBuilder
    private func reminderDestination(_ kind: ReminderKind) -> some View {
        switch kind {
        case .dailyWaterTest:
            DailyLogFormView()
        case .weeklyWaterCheck:
            WeeklyLogFormView()
        case .filterRinse:
            MaintenanceLogFormView(preset: .filterRinse)
        case .filterChange:
            MaintenanceLogFormView(preset: .filterChange)
        case .waterChange:
            MaintenanceLogFormView(preset: .waterChange)
        }
    }

    private func activityRow(_ item: DashboardActivity) -> some View {
        NavigationLink {
            activityDetail(item)
        } label: {
            ActivityRowView(row: item.historyRow, isBromine: viewModel.isBromine, palette: palette)
                .appCard(palette: palette, padding: 12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.delete(item, context: modelContext)
                Task { await notificationService.reschedule(context: modelContext) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func activityDetail(_ item: DashboardActivity) -> some View {
        switch item {
        case .daily(let log):
            DailyLogFormView(existing: log)
        case .weekly(let log):
            WeeklyLogFormView(existing: log)
        case .maintenance(let log):
            MaintenanceLogFormView(existing: log)
        case .usage(let log):
            UsageLogFormView(existing: log)
        }
    }

    private var notificationBellButton: some View {
        Button {
            Task { await handleBellTap() }
        } label: {
            Image(systemName: "bell")
                .font(.body.weight(.semibold))
                .frame(width: AppSpacing.minTap, height: AppSpacing.minTap)
                .overlay(alignment: .topTrailing) {
                    if !viewModel.dueReminders.isEmpty {
                        Text("\(min(viewModel.dueReminders.count, 9))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(palette.color(.accentRed))
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .accessibilityLabel("Notifications")
    }

    private func handleBellTap() async {
        await notificationService.refreshAuthorizationStatus()
        switch notificationService.authorizationStatus {
        case .notDetermined:
            let granted = await notificationService.requestAuthorization()
            if !granted {
                showNotificationsDeniedAlert = true
            }
        case .denied:
            showNotificationsDeniedAlert = true
        default:
            showNotificationSettings = true
        }
    }
}

private struct NotificationSettingsSheet: View {
    @ObservedObject var notificationService: ReminderNotificationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Water test reminders", isOn: Binding(
                        get: { notificationService.remindersEnabled },
                        set: { notificationService.remindersEnabled = $0 }
                    ))
                } footer: {
                    Text("Get reminded when a scheduled maintenance task is due.")
                }

                if notificationService.remindersEnabled {
                    Section("Reminder time") {
                        DatePicker(
                            "Time",
                            selection: Binding(
                                get: { notificationService.preferredReminderTime },
                                set: { notificationService.preferredReminderTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .appPalette(palette.colorScheme)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(HotTubModelContainer.preview)
    .appPalette(.light)
}

// MARK: - iPad dashboard decorations

private struct PadHeroWaveDecoration: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let w = geometry.size.width
                let h = geometry.size.height
                path.move(to: CGPoint(x: 0, y: h * 0.72))
                path.addCurve(
                    to: CGPoint(x: w, y: h * 0.55),
                    control1: CGPoint(x: w * 0.25, y: h * 0.95),
                    control2: CGPoint(x: w * 0.72, y: h * 0.35)
                )
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(Color.white)
        }
    }
}

private struct PadFooterInfoLink: View {
    let palette: AppPalette
    @State private var isPresented = false

    var body: some View {
        Button("About water balance") {
            isPresented = true
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(palette.color(.accentBlue))
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            Text("Typical ranges are for reference only. Test your water and follow product labels before adding chemicals.")
                .font(.footnote)
                .foregroundStyle(palette.color(.textPrimary))
                .padding(16)
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
        }
    }
}
