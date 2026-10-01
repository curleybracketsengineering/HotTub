//
//  TargetRangesSetupView.swift
//  HotTub
//

import SwiftData
import SwiftUI

/// First-run screen. The rest of the app stays closed until these targets are saved.
struct TargetRangesSetupView: View {
    @Bindable var settings: AppSettings

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appPalette) private var palette
    @Environment(\.usePadLayout) private var usePadLayout

    @State private var draft = TargetRangeDraft()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comparison targets")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(palette.color(.textPrimary))
                    Text("These starting numbers are common published ranges. Change them to match your hot tub manual and the instructions on your chemical products. The app compares your readings with the numbers you save here.")
                        .font(.body)
                        .foregroundStyle(palette.color(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                ComparisonTargetEditor(draft: $draft, includesSanitizerPicker: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .padReadableContent(maxWidth: PadContentLayout.settingsMaxWidth)
        }
        .scrollDismissesKeyboard(.interactively)
        .appGroupedScreenBackground(palette)
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
        .onAppear {
            draft = TargetRangeDraft(settings: settings)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if let message = draft.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.color(.accentRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: save) {
                Text("Save these targets")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.validationMessage != nil)

            Text("You can change these later in Settings.")
                .font(.caption)
                .foregroundStyle(palette.color(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(palette.color(.backgroundPrimary))
    }

    private func save() {
        guard draft.validationMessage == nil else { return }
        draft.apply(to: settings, includeSanitizerType: true)
        settings.targetsConfirmed = true
        settings.updatedAt = .now
        try? modelContext.save()
    }
}

/// Shared min/max fields for first-run setup and Settings.
struct ComparisonTargetEditor: View {
    @Binding var draft: TargetRangeDraft
    var includesSanitizerPicker: Bool

    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            if includesSanitizerPicker {
                VStack(alignment: .leading, spacing: AppSpacing.control) {
                    AppSectionHeader(
                        title: "Sanitizer",
                        subtitle: "This chooses which target is used for sanitizer readings."
                    )
                    VStack(spacing: 0) {
                        AppSettingsLabeledRow(label: "Sanitizer") {
                            Picker("Sanitizer", selection: $draft.sanitizerType) {
                                Text("Chlorine").tag("chlorine")
                                Text("Bromine").tag("bromine")
                            }
                            .labelsHidden()
                        }
                    }
                    .appCard(palette: palette, padding: 0)
                }
            }

            rangeCard(
                title: "pH",
                minimum: $draft.phMinimum,
                maximum: $draft.phMaximum,
                unit: ""
            )

            if draft.isBromine {
                rangeCard(
                    title: "Bromine",
                    minimum: $draft.bromineMinimum,
                    maximum: $draft.bromineMaximum,
                    unit: "ppm"
                )
            } else {
                rangeCard(
                    title: "Free chlorine",
                    minimum: $draft.chlorineMinimum,
                    maximum: $draft.chlorineMaximum,
                    unit: "ppm"
                )
                rangeCard(
                    title: "Combined chlorine",
                    minimum: $draft.combinedChlorineMinimum,
                    maximum: $draft.combinedChlorineMaximum,
                    unit: "ppm"
                )
            }
        }
        .animation(.spring(response: 0.35), value: draft.isBromine)
    }

    private func rangeCard(
        title: String,
        minimum: Binding<String>,
        maximum: Binding<String>,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(title: title, subtitle: unit.isEmpty ? nil : unit)
            VStack(spacing: 0) {
                boundRow(title: title, label: "Minimum", text: minimum)
                AppSettingsDivider()
                boundRow(title: title, label: "Maximum", text: maximum)
            }
            .appCard(palette: palette, padding: 0)
        }
    }

    private func boundRow(title: String, label: String, text: Binding<String>) -> some View {
        AppSettingsLabeledRow(label: label) {
            TextField(
                "",
                text: text,
                prompt: AppFormFieldStyle.prompt("0.0", palette: palette)
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .appFormFieldTextStyle(palette)
            .frame(width: 88)
            .accessibilityLabel("\(title) \(label)")
        }
    }
}

/// Settings section. Saves as soon as the entered ranges are valid.
struct ComparisonTargetsSettingsSection: View {
    @Bindable var settings: AppSettings
    var onSave: () -> Void

    @Environment(\.appPalette) private var palette
    @State private var draft = TargetRangeDraft()
    @State private var isLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(
                title: "Comparison targets",
                subtitle: "Water tests are compared with these numbers. Change them to match your hot tub manual and chemical product instructions."
            )

            ComparisonTargetEditor(draft: $draft, includesSanitizerPicker: false)

            if let message = draft.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.color(.accentRed))
            }
        }
        .onAppear {
            draft = TargetRangeDraft(settings: settings)
            draft.sanitizerType = settings.sanitizerType
            isLoaded = true
        }
        .onChange(of: settings.sanitizerType) { _, newValue in
            draft.sanitizerType = newValue
        }
        .onChange(of: draft) { _, newValue in
            guard isLoaded, newValue.validationMessage == nil else { return }
            newValue.apply(to: settings, includeSanitizerType: false)
            onSave()
        }
    }
}
