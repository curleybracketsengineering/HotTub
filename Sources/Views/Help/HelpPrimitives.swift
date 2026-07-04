//
//  HelpPrimitives.swift
//  HotTub
//
//  SwiftUI equivalents of React `CollapsibleSection`, `HelpText`, `BulletPoint`, `InfoBoxes`.
//

import SwiftUI

struct HelpCollapsibleSection<Content: View>: View {
    let title: String
    var defaultExpanded: Bool = false
    @ViewBuilder let content: () -> Content

    @State private var expanded: Bool

    init(title: String, defaultExpanded: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.defaultExpanded = defaultExpanded
        self.content = content
        _expanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.color(.textPrimary))
        }
        .tint(palette.color(.accentBlue))
    }

    @Environment(\.appPalette) private var palette
}

struct HelpParagraph: View {
    let text: String
    var bold: Bool = false
    var topPadding: CGFloat = 0

    var body: some View {
        Text(text)
            .font(bold ? .body.weight(.semibold) : .body)
            .foregroundStyle(palette.color(bold ? .textPrimary : .textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, topPadding)
    }

    @Environment(\.appPalette) private var palette
}

struct HelpBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .foregroundStyle(palette.color(.accentBlue))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @Environment(\.appPalette) private var palette
}

struct HelpIdealRange: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.color(.textSecondary))
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.color(.accentGreen))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(palette.color(.tagGreenFill).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.color(.accentGreen).opacity(0.35), lineWidth: 1)
        )
    }

    @Environment(\.appPalette) private var palette
}

struct HelpWarningBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.color(.statusWarningFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.color(.statusWarningBorder), lineWidth: 1)
            )
    }

    @Environment(\.appPalette) private var palette
}

struct HelpInfoBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.color(.surfaceCard))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.color(.accentBlue).opacity(0.45), lineWidth: 1)
            )
    }

    @Environment(\.appPalette) private var palette
}

struct HelpEducationalDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
                .frame(width: 3)
                .padding(.vertical, 4)
            Text(
                "This information is for educational purposes only. Always follow your hot tub manufacturer's specific instructions and consult product labels for proper chemical handling and dosing. When in doubt, seek advice from a qualified pool/spa professional."
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(red: 0.36, green: 0.25, blue: 0.09))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1, green: 0.95, blue: 0.78))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HelpEducationalDisclaimerShort: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
                .frame(width: 3)
                .padding(.vertical, 4)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(red: 0.36, green: 0.25, blue: 0.09))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1, green: 0.95, blue: 0.78))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
