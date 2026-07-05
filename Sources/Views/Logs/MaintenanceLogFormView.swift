//
//  MaintenanceLogFormView.swift
//  HotTub
//

import SwiftData
import SwiftUI

struct MaintenanceLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let existing: MaintenanceLogEntry?
    let preset: MaintenanceLogPreset?

    @State private var loggedAt: Date = .now
    @State private var action = ""
    @State private var notes = ""
    @State private var filterRinsed = false
    @State private var filterChanged = false
    @State private var waterChange = false

    @State private var alertTitle = "Fix before saving"
    @State private var alertMessage: String?
    @State private var showAlert = false

    init(existing: MaintenanceLogEntry? = nil, preset: MaintenanceLogPreset? = nil) {
        self.existing = existing
        self.preset = preset
    }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "Date & time",
                    selection: $loggedAt,
                    in: ...FormValidation.latestLoggableMoment(),
                    displayedComponents: [.date, .hourAndMinute]
                )
            } header: {
                Text("When")
            }

            Section {
                TextField(
                    "",
                    text: $action,
                    prompt: AppFormFieldStyle.prompt("Action", palette: palette),
                    axis: .vertical
                )
                .lineLimit(2 ... 4)
                .appFormFieldTextStyle(palette)
                Toggle("Rinse filter", isOn: $filterRinsed)
                Toggle("Filter changed", isOn: $filterChanged)
                Toggle("Water change", isOn: $waterChange)
            } header: {
                Text("Service")
            }

            Section {
                TextField(
                    "",
                    text: $notes,
                    prompt: AppFormFieldStyle.prompt("Notes", palette: palette),
                    axis: .vertical
                )
                .lineLimit(3 ... 6)
                .appFormFieldTextStyle(palette)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.color(.backgroundSecondary))
        .navigationTitle(existing == nil ? "Service" : "Edit service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { finish() }
            }
            if existing != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) { deleteLog() }
                }
            }
        }
        .onAppear {
            HotTubModelContainer.seedIfNeeded(in: modelContext)
            if let e = existing {
                loggedAt = e.loggedAt
                action = e.action
                notes = e.notes
                filterRinsed = e.filterRinsed
                filterChanged = e.filterChanged
                waterChange = e.waterChange
            } else {
                applyPreset()
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func applyPreset() {
        guard let preset else { return }
        switch preset {
        case .filterRinse:
            filterRinsed = true
            if action.isEmpty { action = "Rinse filter" }
        case .filterChange:
            filterChanged = true
            if action.isEmpty { action = "Filter changed" }
        case .waterChange:
            waterChange = true
            if action.isEmpty { action = "Water change" }
        }
    }

    private func resolvedAction() -> String {
        var finalAction = action.trimmingCharacters(in: .whitespaces)
        if finalAction.isEmpty {
            var parts: [String] = []
            if filterRinsed { parts.append("Rinse filter") }
            if waterChange { parts.append("Water change") }
            if filterChanged { parts.append("Filter changed") }
            finalAction = parts.joined(separator: ", ")
        }
        return finalAction
    }

    private func finish() {
        let finalAction = resolvedAction()
        let errs = FormValidation.validateMaintenance(
            loggedAt: loggedAt,
            action: finalAction,
            waterChange: waterChange,
            filterChanged: filterChanged,
            filterRinsed: filterRinsed
        )
        if !errs.isEmpty {
            alertTitle = "Fix before saving"
            alertMessage = errs.joined(separator: "\n")
            showAlert = true
            return
        }

        guard commitSave(finalAction: finalAction) else { return }
        refreshReminders()
        dismiss()
    }

    private func refreshReminders() {
        guard !PreviewEnvironment.isActive else { return }
        HotTubDataRefresh.notifyLocalStoreChanged()
        Task { await ReminderNotificationService.shared.rescheduleFromSharedContainer() }
    }

    @discardableResult
    private func commitSave(finalAction: String) -> Bool {
        do {
            if let existing {
                existing.loggedAt = loggedAt
                existing.action = finalAction
                existing.notes = notes
                existing.filterRinsed = filterRinsed
                existing.filterChanged = filterChanged
                existing.waterChange = waterChange
            } else {
                let log = MaintenanceLogEntry(
                    loggedAt: loggedAt,
                    action: finalAction,
                    notes: notes,
                    filterRinsed: filterRinsed,
                    filterChanged: filterChanged,
                    waterChange: waterChange
                )
                modelContext.insert(log)
            }
            try modelContext.save()
            return true
        } catch {
            alertTitle = "Couldn't save"
            alertMessage = "Please try again."
            showAlert = true
            return false
        }
    }

    private func deleteLog() {
        guard let record = existing else { return }
        modelContext.delete(record)
        try? modelContext.save()
        refreshReminders()
        dismiss()
    }
}
