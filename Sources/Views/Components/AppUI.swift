//
//  AppUI.swift
//  HotTub Buddy
//
//  Shared layout primitives (Documents/ui + AppPalette).
//

import SwiftUI

enum AppSpacing {
    static let screenHorizontal: CGFloat = 20
    static let screenTop: CGFloat = 16
    static let screenBottom: CGFloat = 32
    /// Extra bottom inset so scroll content clears the tab bar and stays tappable.
    static let scrollBottom: CGFloat = 88
    static let section: CGFloat = 24
    static let stack: CGFloat = 16
    static let control: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let largeCardRadius: CGFloat = 20
    static let minTap: CGFloat = 44
}

// MARK: - Background

extension View {
    /// Standard padding for main `ScrollView` content (clears tab bar).
    func appScrollScreenPadding() -> some View {
        padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, AppSpacing.scrollBottom)
    }

    func appGroupedScreenBackground(_ palette: AppPalette) -> some View {
        background(palette.color(.backgroundSecondary).ignoresSafeArea())
    }

    func appCard(
        palette: AppPalette,
        radius: CGFloat = AppSpacing.cardRadius,
        padding: CGFloat = 16
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(palette.color(.surfaceCard))
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(palette.color(.separator).opacity(0.35), lineWidth: 1)
            }
    }
}

// MARK: - Section header

struct AppSectionHeader: View {
    let title: String
    var subtitle: String?

    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.color(.textPrimary))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty state

struct AppEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.color(.textTertiary))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.color(.textPrimary))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.color(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .appCard(palette: palette)
    }
}

// MARK: - Filter chip

struct AppFilterChip: View {
    /// Uniform width sized for the "Weekly" label at caption + horizontal inset.
    private static let uniformWidth: CGFloat = 72

    let title: String
    @Binding var isOn: Bool

    @Environment(\.appPalette) private var palette

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35)) {
                isOn.toggle()
            }
        } label: {
            Text(title)
                .font(.caption.weight(isOn ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: Self.uniformWidth)
                .frame(minHeight: AppSpacing.minTap)
                .background(isOn ? palette.color(.tagBlueFill) : Color.clear)
                .foregroundStyle(isOn ? palette.color(.accentBlue) : palette.color(.textSecondary))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isOn ? palette.color(.accentBlue) : palette.color(.separator),
                            lineWidth: isOn ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings rows (card interior)

struct AppSettingsDivider: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        Divider()
            .overlay(palette.color(.separator).opacity(0.5))
            .padding(.leading, 16)
    }
}

struct AppSettingsLabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.body)
                .foregroundStyle(palette.color(.textPrimary))
            Spacer(minLength: 16)
            content
        }
        .padding(.horizontal, 16)
        .frame(minHeight: AppSpacing.minTap)
    }
}

struct AppSettingsValueRow: View {
    let label: String
    let value: String

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(palette.color(.textPrimary))
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.color(.textSecondary))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: AppSpacing.minTap)
    }
}

// MARK: - Info popover

struct AppInfoButton: View {
    let message: String
    var accessibilityLabel: String = "More information"
    var foreground: Color?

    @State private var isPresented = false
    @Environment(\.appPalette) private var palette

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.title3)
                .foregroundStyle(foreground ?? palette.color(.textSecondary))
                .frame(width: AppSpacing.minTap, height: AppSpacing.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isPresented) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(palette.color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Form fields (card-style inputs)

enum AppFormFieldStyle {
    static func prompt(_ placeholder: String, palette: AppPalette) -> Text {
        Text(placeholder).foregroundStyle(palette.color(.textTertiary))
    }
}

extension View {
    /// Entered text colour for form `TextField`s (placeholder uses `AppFormFieldStyle.prompt`).
    func appFormFieldTextStyle(_ palette: AppPalette, weight: Font.Weight = .regular) -> some View {
        font(.body.weight(weight))
            .foregroundStyle(palette.color(.textPrimary))
    }
}

struct AppFormNotesField: View {
    @Binding var text: String
    var placeholder: String = "Optional notes"

    @Environment(\.appPalette) private var palette

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: AppFormFieldStyle.prompt(placeholder, palette: palette),
            axis: .vertical
        )
        .lineLimit(3 ... 6)
        .appFormFieldTextStyle(palette)
        .frame(minHeight: 88, alignment: .topLeading)
    }
}

struct AppFormCardTextField: View {
    let placeholder: String
    @Binding var text: String
    var lineLimit: ClosedRange<Int> = 1 ... 3
    var minHeight: CGFloat = 50

    @Environment(\.appPalette) private var palette

    private let fieldRadius: CGFloat = 14

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: AppFormFieldStyle.prompt(placeholder, palette: palette),
            axis: .vertical
        )
        .lineLimit(lineLimit)
        .appFormFieldTextStyle(palette)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: fieldRadius, style: .continuous)
                .fill(palette.color(.backgroundSecondary))
        )
        .overlay {
            RoundedRectangle(cornerRadius: fieldRadius, style: .continuous)
                .strokeBorder(palette.color(.separator).opacity(0.5), lineWidth: 1)
        }
    }
}

struct AppMetricInputBox: View {
    var systemImage: String?
    let placeholder: String
    @Binding var text: String
    var blurValidator: ((String) -> String?)? = nil

    @Environment(\.appPalette) private var palette
    @FocusState private var isFocused: Bool
    @State private var errorMessage: String?

    private let fieldRadius: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.medium))
                        .foregroundStyle(palette.color(.accentBlue))
                        .frame(width: 24, alignment: .center)
                }
                TextField(
                    "",
                    text: $text,
                    prompt: AppFormFieldStyle.prompt(placeholder, palette: palette)
                )
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .appFormFieldTextStyle(
                    palette,
                    weight: text.trimmingCharacters(in: .whitespaces).isEmpty ? .regular : .semibold
                )
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: fieldRadius, style: .continuous)
                    .fill(palette.color(.backgroundSecondary))
            )
            .overlay {
                RoundedRectangle(cornerRadius: fieldRadius, style: .continuous)
                    .strokeBorder(
                        errorMessage == nil
                            ? palette.color(.separator).opacity(0.5)
                            : palette.color(.statusErrorBorder),
                        lineWidth: 1
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(palette.color(.statusErrorText))
            }
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused else { return }
            validateOnBlur()
        }
        .onChange(of: text) { _, _ in
            if isFocused, errorMessage != nil {
                errorMessage = nil
            }
        }
    }

    private func validateOnBlur() {
        guard let blurValidator else {
            errorMessage = nil
            return
        }
        errorMessage = blurValidator(text)
    }
}

struct AppFormScreenSection<Content: View>: View {
    let title: String
    var helpRequest: HelpSheetRequest?
    @Binding var presentedHelp: HelpSheetRequest?
    @ViewBuilder let content: () -> Content

    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            if let helpRequest {
                AppFormSectionHeader(
                    title: title,
                    helpRequest: helpRequest,
                    presentedHelp: $presentedHelp
                )
            } else {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.color(.textPrimary))
            }

            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                content()
            }
            .appCard(palette: palette)
        }
    }
}

struct AppSimpleMetricField: View {
    let title: String
    var systemImage: String?
    let placeholder: String
    @Binding var text: String
    var blurValidator: ((String) -> String?)? = nil

    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.color(.textSecondary))
            AppMetricInputBox(
                systemImage: systemImage,
                placeholder: placeholder,
                text: $text,
                blurValidator: blurValidator
            )
        }
    }
}

// MARK: - Help topic sheet (React HelpModal per-field buttons)

struct AppHelpTopicButton: View {
    let request: HelpSheetRequest
    @Binding var presentedRequest: HelpSheetRequest?
    var accessibilityLabel: String?

    @Environment(\.appPalette) private var palette

    var body: some View {
        Button {
            presentedRequest = request
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.body)
                .foregroundStyle(palette.color(.accentBlue))
                .frame(width: AppSpacing.minTap, height: AppSpacing.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? request.topic.screenTitle)
    }
}

struct AppFormFieldLabel: View {
    let title: String
    let helpRequest: HelpSheetRequest
    @Binding var presentedHelp: HelpSheetRequest?

    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.color(.textSecondary))
            Spacer(minLength: 0)
            AppHelpTopicButton(request: helpRequest, presentedRequest: $presentedHelp)
        }
    }
}

struct AppFormSectionHeader: View {
    let title: String
    var helpRequest: HelpSheetRequest?
    @Binding var presentedHelp: HelpSheetRequest?

    var body: some View {
        if let helpRequest {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                Spacer(minLength: 0)
                AppHelpTopicButton(request: helpRequest, presentedRequest: $presentedHelp)
            }
        } else {
            Text(title)
        }
    }
}

struct AppLabeledFormField: View {
    let title: String
    let helpRequest: HelpSheetRequest
    @Binding var presentedHelp: HelpSheetRequest?
    var systemImage: String?
    var placeholder: String = ""
    @Binding var text: String
    var blurValidator: ((String) -> String?)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppFormFieldLabel(title: title, helpRequest: helpRequest, presentedHelp: $presentedHelp)
            AppMetricInputBox(
                systemImage: systemImage,
                placeholder: placeholder,
                text: $text,
                blurValidator: blurValidator
            )
        }
    }
}

extension View {
    func helpSheet(
        presentedHelp: Binding<HelpSheetRequest?>,
        isBromine: Bool,
        isMetric: Bool
    ) -> some View {
        sheet(item: presentedHelp) { request in
            HelpSheetView(request: request, isBromine: isBromine, isMetric: isMetric)
        }
    }
}

// MARK: - Primary button

struct AppPrimaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.appPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(palette.color(.accentBlue))
        .controlSize(.large)
    }
}
