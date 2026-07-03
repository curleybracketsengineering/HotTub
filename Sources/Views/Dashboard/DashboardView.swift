//
//  DashboardView.swift
//  HotTub Buddy
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.openURL) private var openURL
    @ObservedObject private var notificationService = ReminderNotificationService.shared
    @StateObject private var viewModel = DashboardViewModel()

    @State private var showNotificationSettings = false
    @State private var showNotificationsDeniedAlert = false
    @State private var navigateToDailyLog = false
    @State private var navigateToWeeklyCheck = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                statusCard
                actionsSection
                recentRecords
                remindersSection
            }
            .appScrollScreenPadding()
        }
        .appGroupedScreenBackground(palette)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await handleBellTap() }
                } label: {
                    Image(systemName: "bell")
                        .font(.body.weight(.semibold))
                        .frame(width: AppSpacing.minTap, height: AppSpacing.minTap)
                }
                .accessibilityLabel("Notifications")
            }
        }
        .task {
            viewModel.reload(context: modelContext)
            await notificationService.refreshAuthorizationStatus()
            await notificationService.reschedule(context: modelContext)
        }
        .onAppear { viewModel.reload(context: modelContext) }
        .refreshable {
            viewModel.reload(context: modelContext)
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
                    systemImage: "drop.fill",
                    fillToken: .tagBlueFill,
                    iconToken: .accentBlue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                MaintenanceLogFormView()
            } label: {
                subActionTile(
                    title: "Record maintenance",
                    systemImage: "wrench.fill",
                    fillToken: .tagGreenFill,
                    iconToken: .accentGreen
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                HistoryView(isTabRoot: false)
            } label: {
                subActionTile(
                    title: "View history",
                    systemImage: "clock.arrow.circlepath",
                    fillToken: .tagBlueFill,
                    iconToken: .accentIndigo
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

    private var recentRecords: some View {
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
                ForEach(viewModel.recentRecords) { item in
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
