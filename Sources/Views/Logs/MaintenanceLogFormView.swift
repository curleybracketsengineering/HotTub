//
//  MaintenanceLogFormView.swift
//  HotTub Buddy
//

import SwiftData
import SwiftUI

struct MaintenanceLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let existing: MaintenanceLogEntry?

    @State private var loggedAt: Date = .now
    @State private var action = ""
    @State private var notes = ""
    @State private var filterChanged = false
    @State private var waterChange = false

    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var draftRecord: MaintenanceLogEntry?
    @State private var autoSaveScheduler = FormAutoSaveScheduler()
    @State private var skipAutoSave = true

    init(existing: MaintenanceLogEntry? = nil) {
        self.existing = existing
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Date & time", selection: $loggedAt, displayedComponents: [.date, .hourAndMinute])
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
                Toggle("Water change", isOn: $waterChange)
                Toggle("Filter changed", isOn: $filterChanged)
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
            if activeRecord != nil {
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
                filterChanged = e.filterChanged
                waterChange = e.waterChange
            }
            skipAutoSave = false
        }
        .onChange(of: formSnapshot) { _, _ in scheduleAutoSave() }
        .onDisappear {
            autoSaveScheduler.flush { persistDraft() }
            if existing == nil, let draft = draftRecord, isEmptyDraft(draft) {
                modelContext.delete(draft)
                try? modelContext.save()
            }
        }
        .alert("Cannot save", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var activeRecord: MaintenanceLogEntry? {
        existing ?? draftRecord
    }

    private var formSnapshot: MaintenanceFormSnapshot {
        MaintenanceFormSnapshot(
            loggedAt: loggedAt,
            action: action,
            notes: notes,
            filterChanged: filterChanged,
            waterChange: waterChange
        )
    }

    private var hasDraftContent: Bool {
        !action.trimmingCharacters(in: .whitespaces).isEmpty
            || !notes.trimmingCharacters(in: .whitespaces).isEmpty
            || filterChanged
            || waterChange
    }

    private func resolvedAction() -> String {
        var finalAction = action.trimmingCharacters(in: .whitespaces)
        if finalAction.isEmpty {
            var parts: [String] = []
            if waterChange { parts.append("Water change") }
            if filterChanged { parts.append("Filter changed") }
            finalAction = parts.joined(separator: ", ")
        }
        return finalAction
    }

    private func scheduleAutoSave() {
        guard !skipAutoSave else { return }
        autoSaveScheduler.schedule { persistDraft() }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard existing != nil || hasDraftContent else { return true }

        let finalAction = resolvedAction()
        let record: MaintenanceLogEntry
        if let existing {
            record = existing
        } else if let draftRecord {
            record = draftRecord
        } else {
            let log = MaintenanceLogEntry(
                loggedAt: loggedAt,
                action: finalAction,
                notes: notes,
                filterChanged: filterChanged,
                waterChange: waterChange
            )
            modelContext.insert(log)
            draftRecord = log
            record = log
        }

        record.loggedAt = loggedAt
        record.action = finalAction
        record.notes = notes
        record.filterChanged = filterChanged
        record.waterChange = waterChange
        try? modelContext.save()
        return true
    }

    private func finish() {
        let finalAction = resolvedAction()
        let errs = FormValidation.validateMaintenance(
            loggedAt: loggedAt,
            action: finalAction,
            waterChange: waterChange,
            filterChanged: filterChanged
        )
        if !errs.isEmpty {
            alertMessage = errs.joined(separator: "\n")
            showAlert = true
            return
        }

        autoSaveScheduler.flush { persistDraft() }
        dismiss()
    }

    private func isEmptyDraft(_ record: MaintenanceLogEntry) -> Bool {
        record.action.trimmingCharacters(in: .whitespaces).isEmpty
            && record.notes.trimmingCharacters(in: .whitespaces).isEmpty
            && !record.filterChanged
            && !record.waterChange
    }

    private func deleteLog() {
        guard let record = activeRecord else { return }
        modelContext.delete(record)
        try? modelContext.save()
        dismiss()
    }
}

private struct MaintenanceFormSnapshot: Equatable {
    var loggedAt: Date
    var action: String
    var notes: String
    var filterChanged: Bool
    var waterChange: Bool
}
