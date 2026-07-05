//
//  SetupView.swift
//  HotTub
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [AppSettings]
    @Environment(\.appPalette) private var palette

    var body: some View {
        Group {
            if let settings = settingsRows.first {
                SetupSettingsForm(settings: settings)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .appGroupedScreenBackground(palette)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            HotTubModelContainer.seedIfNeeded(in: modelContext)
        }
    }
}

private struct SetupSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.isLandscape) private var isLandscape
    @ObservedObject private var notificationService = ReminderNotificationService.shared

    @State private var showImporter = false
    @State private var showBackupPicker = false
    @State private var backupFiles: [URL] = []
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showDeleteSuspiciousUsageConfirm = false

    @Query(sort: \UsageLogEntry.loggedAt, order: .reverse) private var usageLogs: [UsageLogEntry]
    @Query(sort: \HotTubDailyLog.loggedAt, order: .reverse) private var dailyLogs: [HotTubDailyLog]

    private var suspiciousUsageLogs: [UsageLogEntry] {
        UsageLogDiagnostics.entriesMatchingSanitizerPPM(usage: usageLogs, daily: dailyLogs)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                Group {
                    if usePadLayout && isLandscape {
                        padSettingsContent
                    } else {
                        stackedSettingsContent
                    }
                }
                .appAdaptiveScrollPadding(usePadLayout: usePadLayout)
                .padReadableContent(maxWidth: settingsContentMaxWidth(availableWidth: geometry.size.width))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .scrollDismissesKeyboard(.interactively)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            importCSV(from: result)
        }
        .sheet(isPresented: $showBackupPicker) {
            BackupCSVPickerSheet(
                files: backupFiles,
                onSelect: { url in
                    showBackupPicker = false
                    importCSVFile(at: url)
                },
                onChooseFile: {
                    showBackupPicker = false
                    showImporter = true
                }
            )
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Delete suspicious usage sessions?",
            isPresented: $showDeleteSuspiciousUsageConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(suspiciousUsageLogs.count) session\(suspiciousUsageLogs.count == 1 ? "" : "s")", role: .destructive) {
                deleteSuspiciousUsageLogs()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These sessions have people counts that match chlorine readings on the same day — they were likely imported or logged by mistake.")
        }
    }

    private func settingsContentMaxWidth(availableWidth: CGFloat) -> CGFloat {
        if usePadLayout && !isLandscape {
            return availableWidth * PadContentLayout.settingsPortraitWidthFraction
        }
        if usePadLayout {
            return PadContentLayout.dashboardMaxWidth
        }
        return PadContentLayout.readableMaxWidth
    }

    private var stackedSettingsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            hotTubSection
            maintenanceScheduleSection
            dataSection
            safetySection
        }
    }

    private var padSettingsContent: some View {
        HStack(alignment: .top, spacing: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                hotTubSection
                maintenanceScheduleSection
                dataSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            safetySection
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hotTubSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(
                title: "Hot tub",
                subtitle: "Capacity, units, and sanitizer type"
            )

            VStack(spacing: 0) {
                AppSettingsLabeledRow(label: "Capacity") {
                    TextField(
                        "",
                        value: $settings.capacity,
                        format: .number,
                        prompt: AppFormFieldStyle.prompt("1000", palette: palette)
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .appFormFieldTextStyle(palette)
                    .frame(width: 120)
                    .onChange(of: settings.capacity) { _, _ in touch() }
                }

                AppSettingsDivider()

                AppSettingsLabeledRow(label: "Unit") {
                    Picker("Unit", selection: $settings.capacityUnit) {
                        Text("Litres").tag("liters")
                        Text("UK Gallons").tag("uk_gallons")
                        Text("US Gallons").tag("us_gallons")
                    }
                    .labelsHidden()
                    .onChange(of: settings.capacityUnit) { _, _ in touch() }
                }

                AppSettingsDivider()

                AppSettingsLabeledRow(label: "Measurements") {
                    Picker("Measurements", selection: $settings.measurementSystem) {
                        Text("Metric").tag("metric")
                        Text("Imperial").tag("imperial")
                    }
                    .labelsHidden()
                    .onChange(of: settings.measurementSystem) { _, _ in touch() }
                }

                AppSettingsDivider()

                AppSettingsLabeledRow(label: "Sanitizer") {
                    Picker("Sanitizer", selection: $settings.sanitizerType) {
                        Text("Chlorine").tag("chlorine")
                        Text("Bromine").tag("bromine")
                    }
                    .labelsHidden()
                    .onChange(of: settings.sanitizerType) { _, _ in touch() }
                }
            }
            .appCard(palette: palette, padding: 0)
        }
    }

    private var maintenanceScheduleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(
                title: "Maintenance schedule",
                subtitle: "Suggested intervals — adjust to match your spa manufacturer. Reminders appear on Home."
            )

            VStack(spacing: 0) {
                ReminderSettingRow(
                    title: "Water test",
                    isEnabled: $settings.reminderWaterTestEnabled,
                    onChange: touchAndReschedule
                ) {
                    ReminderIntervalPicker(
                        selection: $settings.reminderWaterTestDays,
                        options: [
                            (1, "Every day"),
                            (2, "Every 2 days"),
                            (3, "Every 3 days"),
                        ],
                        onChange: touchAndReschedule
                    )
                }

                AppSettingsDivider()

                ReminderSettingRow(
                    title: "Full water check",
                    isEnabled: $settings.reminderWeeklyCheckEnabled,
                    onChange: touchAndReschedule
                ) {
                    ReminderIntervalPicker(
                        selection: $settings.reminderWeeklyCheckDays,
                        options: [
                            (7, "Weekly"),
                            (14, "Every 2 weeks"),
                        ],
                        onChange: touchAndReschedule
                    )
                }

                AppSettingsDivider()

                ReminderSettingRow(
                    title: "Rinse filter",
                    isEnabled: $settings.reminderFilterRinseEnabled,
                    onChange: touchAndReschedule
                ) {
                    ReminderIntervalPicker(
                        selection: $settings.reminderFilterRinseDays,
                        options: [
                            (7, "Weekly"),
                            (14, "Every 2 weeks"),
                            (30, "Monthly"),
                        ],
                        onChange: touchAndReschedule
                    )
                }

                AppSettingsDivider()

                ReminderSettingRow(
                    title: "Change filter",
                    isEnabled: $settings.reminderFilterChangeEnabled,
                    onChange: touchAndReschedule
                ) {
                    ReminderMonthsPicker(
                        selection: $settings.reminderFilterChangeMonths,
                        options: [
                            (6, "Every 6 months"),
                            (12, "Every 12 months"),
                            (18, "Every 18 months"),
                        ],
                        onChange: touchAndReschedule
                    )
                }

                AppSettingsDivider()

                ReminderSettingRow(
                    title: "Water change",
                    isEnabled: $settings.reminderWaterChangeEnabled,
                    onChange: touchAndReschedule
                ) {
                    ReminderIntervalPicker(
                        selection: $settings.reminderWaterChangeDays,
                        options: [
                            (60, "Every 2 months"),
                            (90, "Every 3 months"),
                            (120, "Every 4 months"),
                        ],
                        onChange: touchAndReschedule
                    )
                }

                AppSettingsDivider()

                AppSettingsLabeledRow(label: "Reminder time") {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { notificationService.preferredReminderTime },
                            set: { notificationService.preferredReminderTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                AppSettingsDivider()

                AppSettingsLabeledRow(label: "Push notifications") {
                    Toggle("", isOn: Binding(
                        get: { notificationService.remindersEnabled },
                        set: { notificationService.remindersEnabled = $0 }
                    ))
                    .labelsHidden()
                }
            }
            .appCard(palette: palette, padding: 0)
        }
    }

    private func touchAndReschedule() {
        touch()
        guard !PreviewEnvironment.isActive else { return }
        Task { await notificationService.reschedule(context: modelContext) }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(
                title: "Data",
                subtitle: "Records sync automatically across your devices via the iCloud account on this device. CSV backup and import remain available for manual backup or restore."
            )

            VStack(spacing: 0) {
                AppSettingsActionRow(
                    label: "Save CSV backup",
                    systemImage: "arrow.down.doc"
                ) {
                    saveCSVBackup()
                }

                AppSettingsDivider()

                AppSettingsActionRow(
                    label: "Import records",
                    systemImage: "square.and.arrow.down"
                ) {
                    presentBackupPicker()
                }

                if !usageLogs.isEmpty {
                    AppSettingsDivider()

                    AppSettingsLabeledRow(label: "Usage sessions") {
                        Text("\(usageLogs.count)")
                            .foregroundStyle(palette.color(.textSecondary))
                    }

                    if !suspiciousUsageLogs.isEmpty {
                        AppSettingsDivider()

                        AppSettingsActionRow(
                            label: "Remove suspicious usage (\(suspiciousUsageLogs.count))",
                            systemImage: "trash",
                            accentToken: .accentRed
                        ) {
                            showDeleteSuspiciousUsageConfirm = true
                        }
                    }
                }
            }
            .appCard(palette: palette, padding: 0)
        }
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(title: "Safety information")

            SetupDisclaimerView(
                isBromine: settings.sanitizerType == "bromine",
                isMetric: settings.measurementSystem == "metric"
            )
        }
    }

    private func touch() {
        settings.updatedAt = .now
        settings.temperatureUnit = settings.measurementSystem == "metric" ? "celsius" : "fahrenheit"
        try? modelContext.save()
    }

    private func saveCSVBackup() {
        do {
            let csv = try HotTubCSVService.exportCSV(in: modelContext)
            let url = try CSVBackupFileWriter.writeBackupCSV(
                text: csv,
                filename: HotTubCSVService.suggestedExportFilename()
            )
            presentAlert(
                title: "Backup saved",
                message: "Saved as \(url.lastPathComponent). Use Import records to load it from Backups."
            )
        } catch {
            presentAlert(title: "Backup failed", message: error.localizedDescription)
        }
    }

    private func presentBackupPicker() {
        do {
            backupFiles = try CSVBackupFileWriter.listBackupCSVFiles()
            showBackupPicker = true
        } catch {
            presentAlert(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func deleteSuspiciousUsageLogs() {
        let count = suspiciousUsageLogs.count
        guard count > 0 else { return }
        for log in suspiciousUsageLogs {
            modelContext.delete(log)
        }
        try? modelContext.save()
        presentAlert(
            title: "Removed suspicious usage",
            message: "Deleted \(count) session\(count == 1 ? "" : "s") whose people counts matched chlorine readings."
        )
    }

    private func importCSV(from result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if error is CancellationError { return }
            presentAlert(title: "Import failed", message: error.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSVFile(at: url, needsSecurityScope: true)
        }
    }

    private func importCSVFile(at url: URL, needsSecurityScope: Bool = false) {
        let accessGranted = needsSecurityScope ? url.startAccessingSecurityScopedResource() : true
        guard accessGranted else {
            presentAlert(title: "Import failed", message: HotTubCSVError.unreadable.errorDescription ?? "Could not open the file.")
            return
        }
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self)
            let importResult = try HotTubCSVService.importCSV(text, in: modelContext)
            presentAlert(title: "Import complete", message: importResult.summary)
        } catch {
            presentAlert(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

private struct BackupCSVPickerSheet: View {
    let files: [URL]
    let onSelect: (URL) -> Void
    let onChooseFile: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    ContentUnavailableView(
                        "No backups yet",
                        systemImage: "doc",
                        description: Text("Save a CSV backup first, or choose a file from elsewhere.")
                    )
                } else {
                    List(files, id: \.path) { url in
                        Button {
                            onSelect(url)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(url.lastPathComponent)
                                    .font(.body)
                                    .foregroundStyle(palette.color(.textPrimary))
                                if let date = modifiedDate(for: url) {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Choose another file…") {
                        onChooseFile()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func modifiedDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

private struct ReminderSettingRow<IntervalContent: View>: View {
    let title: String
    @Binding var isEnabled: Bool
    var onChange: () -> Void
    @ViewBuilder let intervalContent: () -> IntervalContent

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.color(.textPrimary))
                .lineLimit(1)
                .layoutPriority(-1)

            Spacer(minLength: 8)

            if isEnabled {
                intervalContent()
                    .layoutPriority(1)
            }

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, _ in onChange() }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: AppSpacing.minTap)
    }
}

private struct ReminderIntervalPicker: View {
    @Binding var selection: Int
    let options: [(Int, String)]
    var onChange: () -> Void

    @Environment(\.appPalette) private var palette

    var body: some View {
        Picker("Interval", selection: $selection) {
            ForEach(options, id: \.0) { value, label in
                Text(label).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .font(.subheadline)
        .foregroundStyle(palette.color(.accentBlue))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: selection) { _, _ in onChange() }
    }
}

private struct ReminderMonthsPicker: View {
    @Binding var selection: Int
    let options: [(Int, String)]
    var onChange: () -> Void

    @Environment(\.appPalette) private var palette

    var body: some View {
        Picker("Interval", selection: $selection) {
            ForEach(options, id: \.0) { value, label in
                Text(label).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .font(.subheadline)
        .foregroundStyle(palette.color(.accentBlue))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: selection) { _, _ in onChange() }
    }
}

private struct AppSettingsActionRow: View {
    let label: String
    let systemImage: String
    var isDisabled = false
    var accentToken: PaletteToken = .accentBlue
    let action: () -> Void

    @Environment(\.appPalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundStyle(palette.color(.textPrimary))
                Spacer(minLength: 16)
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.color(accentToken))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: AppSpacing.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
