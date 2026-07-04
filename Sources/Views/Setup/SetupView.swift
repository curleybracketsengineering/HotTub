//
//  SetupView.swift
//  HotTub Buddy
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
        .navigationTitle("Setup")
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

    @State private var showImporter = false
    @State private var showBackupPicker = false
    @State private var backupFiles: [URL] = []
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                hotTubSection
                dataSection
                safetySection
            }
            .appScrollScreenPadding()
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

private struct AppSettingsActionRow: View {
    let label: String
    let systemImage: String
    var isDisabled = false
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
                    .foregroundStyle(palette.color(.accentBlue))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: AppSpacing.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
