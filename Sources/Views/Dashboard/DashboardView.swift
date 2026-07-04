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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await handleBellTap() }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.body.weight(.semibold))
                            .frame(width: AppSpacing.minTap, height: AppSpacing.minTap)

                        if usePadLayout, !viewModel.dueReminders.isEmpty {
                            Text("\(min(viewModel.dueReminders.count, 9))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(palette.color(.accentRed))
                                .clipShape(Circle())
                                .offset(x: 6, y: -4)
                        }
                    }
                }
                .accessibilityLabel("Notifications")
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
            Text("Turn on notifications in Settings to get water test reminders.")
        }
        .navigationDestination(isPresented: $navigateToDailyLog) {
            DailyLogFormView()
        }
        .navigationDestination(isPresented: $navigateToWeeklyCheck) {
            WeeklyLogFormView()
        }
        .onChange(of: notificationService.pendingDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .dailyLog:
                navigateToDailyLog = true
            case .weeklyCheck:
                navigateToWeeklyCheck = true
            }
            notificationService.pendingDestination = nil
        }
    }

    private var phoneDashboardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            statusCard
            actionsSection
            recentRecords(limit: 3)
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

        return ZStack {
            statusCardGradient(hasData: hasData, isStale: isStale || isDailyDue)

            PadHeroWaveDecoration()
                .opacity(0.18)

            HStack(alignment: .top, spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundStyle(palette.color(.accentBlue))
                            .frame(width: 48, height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(padHeroHeadline(isDailyDue: isDailyDue, hasData: hasData))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(palette.color(.onAccent))

                            if let log {
                                Text("Last checked \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))")
                                    .font(.subheadline)
                                    .foregroundStyle(palette.color(.onAccent).opacity(0.8))
                            } else {
                                Text("No readings logged yet")
                                    .font(.subheadline)
                                    .foregroundStyle(palette.color(.onAccent).opacity(0.8))
                            }
                        }
                    }

                    if hasData, inRange {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("Last result was within range")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(palette.color(.onAccent))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 16) {
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
                    }

                    HStack(alignment: .top, spacing: 24) {
                        padHeroMetric(
                            label: viewModel.isBromine ? "Bromine" : "Chlorine",
                            value: sanitizerDisplay(log),
                            ideal: sanitizerIdealLabel
                        )
                        padHeroMetric(
                            label: "pH",
                            value: log?.ph.map { String(format: "%.1f", $0) } ?? "--",
                            ideal: "Ideal 7.2 – 7.8"
                        )
                    }
                }
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.largeCardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func padHeroHeadline(isDailyDue: Bool, hasData: Bool) -> String {
        if !hasData { return "Check your water today" }
        if isDailyDue { return "Water test due today" }
        return "Water status looks good"
    }

    private func padHeroMetric(label: String, value: String, ideal: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.color(.onAccent).opacity(0.75))
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.color(.onAccent))
            Text(ideal)
                .font(.caption2)
                .foregroundStyle(palette.color(.onAccent).opacity(0.65))
        }
    }

    private var sanitizerIdealLabel: String {
        if viewModel.isBromine {
            return "Ideal 3.0 – 5.0 ppm"
        }
        return "Ideal 1.0 – 3.0 ppm"
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
                NavigationLink("See all") {
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
                    ForEach(Array(viewModel.recentRecords.prefix(5).enumerated()), id: \.element.id) { index, item in
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
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reminders")
                    .font(.headline)
                    .foregroundStyle(palette.color(.textPrimary))
                Spacer()
                Button("Manage") {
                    Task { await handleBellTap() }
                }
                .font(.subheadline.weight(.medium))
            }

            if viewModel.dueReminders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(palette.color(.accentGreen))
                    Text("All caught up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.color(.textPrimary))
                    Text("No water tests or weekly checks due right now.")
                        .font(.caption)
                        .foregroundStyle(palette.color(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(palette: palette)
            } else {
                VStack(spacing: AppSpacing.control) {
                    ForEach(viewModel.dueReminders) { reminder in
                        padReminderCard(reminder)
                    }
                }

                Button {
                    Task { await handleBellTap() }
                } label: {
                    Text("View all reminders")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.color(.accentBlue))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func padReminderCard(_ reminder: HomeReminder) -> some View {
        let urgency = reminder.urgency()
        let colors = padReminderColors(for: urgency)

        return NavigationLink {
            reminderDestination(reminder.kind)
        } label: {
            HStack(spacing: AppSpacing.control) {
                Image(systemName: "calendar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(colors.icon)
                    .frame(width: 40, height: 40)
                    .background(colors.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.padTitle)
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

    private struct PadReminderColors {
        let background: Color
        let border: Color
        let icon: Color
        let iconBackground: Color
        let badgeBackground: Color
        let badgeText: Color
    }

    private func padReminderColors(for urgency: HomeReminder.Urgency) -> PadReminderColors {
        switch urgency {
        case .overdue:
            return PadReminderColors(
                background: palette.color(.statusErrorFill),
                border: palette.color(.statusErrorBorder),
                icon: palette.color(.accentRed),
                iconBackground: palette.color(.statusErrorFill),
                badgeBackground: palette.color(.accentRed).opacity(0.16),
                badgeText: palette.color(.statusErrorText)
            )
        case .dueToday:
            return PadReminderColors(
                background: palette.color(.statusWarningFill),
                border: palette.color(.statusWarningBorder),
                icon: palette.color(.accentOrange),
                iconBackground: palette.color(.statusWarningFill),
                badgeBackground: palette.color(.accentOrange).opacity(0.16),
                badgeText: palette.color(.statusWarningText)
            )
        case .upcoming:
            return PadReminderColors(
                background: palette.color(.accentYellow).opacity(0.12),
                border: palette.color(.accentYellow).opacity(0.35),
                icon: palette.color(.accentOrange),
                iconBackground: palette.color(.accentYellow).opacity(0.2),
                badgeBackground: palette.color(.accentYellow).opacity(0.25),
                badgeText: palette.color(.textPrimary)
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
        let gradient = statusCardGradient(hasData: hasData, isStale: isStale)

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
                    Text("Last checked: \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))")
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

    private func statusCardGradient(hasData: Bool, isStale: Bool) -> LinearGradient {
        let colors: [Color]
        if !hasData {
            colors = [palette.color(.heroEmptyStart), palette.color(.heroEmptyEnd)]
        } else if isStale {
            colors = [
                palette.color(.heroEmptyStart),
                palette.color(.heroEmptyEnd).opacity(0.88),
            ]
        } else {
            colors = [
                palette.color(.accentBlue),
                palette.color(.accentIndigo).opacity(0.92),
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
                    viewModel.statusSummary(ph: $0.ph, sanitizer: $0.primarySanitizerPpm)
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
                Text("Last checked \(RelativeDateFormatter.relativeDayAndTime(for: log.loggedAt))")
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
                    title: "Weekly water check",
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

    private func recentRecords(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            HStack(alignment: .firstTextBaseline) {
                AppSectionHeader(title: "Recent records")
                Spacer()
                NavigationLink("See all") {
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
                ForEach(viewModel.recentRecords.prefix(limit)) { item in
                    activityRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        if !viewModel.dueReminders.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.control) {
                AppSectionHeader(title: "Reminders")

                ForEach(viewModel.dueReminders) { reminder in
                    reminderRow(reminder)
                }
            }
        }
    }

    private func reminderRow(_ reminder: HomeReminder) -> some View {
        NavigationLink {
            reminderDestination(reminder.kind)
        } label: {
            HStack(spacing: AppSpacing.control) {
                Image(systemName: "calendar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.color(.accentOrange))
                    .frame(width: 40, height: 40)
                    .background(palette.color(.statusWarningFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.color(.textPrimary))
                    Text(reminder.dueSubtitle())
                        .font(.caption)
                        .foregroundStyle(palette.color(.textSecondary))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.color(.textTertiary))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(palette.color(.statusWarningFill))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(palette.color(.statusWarningBorder).opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func reminderDestination(_ kind: ReminderKind) -> some View {
        switch kind {
        case .dailyWaterTest:
            DailyLogFormView()
        case .weeklyWaterCheck:
            WeeklyLogFormView()
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
                    Text("Get reminded when a daily test or weekly check is due.")
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
