//
//  Placeholders.swift
//  HotTub
//

import SwiftUI

struct ActivityHubView: View {
    @Environment(\.appPalette) private var palette

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.control),
        GridItem(.flexible(), spacing: AppSpacing.control),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                AppSectionHeader(
                    title: "New entry",
                    subtitle: "Choose what you want to log"
                )

                LazyVGrid(columns: columns, spacing: AppSpacing.control) {
                    ForEach(ActivityLogKind.allCases) { kind in
                        NavigationLink {
                            kind.formDestination
                        } label: {
                            entryTile(
                                title: kind.hubTitle,
                                systemImage: kind.systemImage,
                                fillToken: kind.fillToken,
                                iconToken: kind.iconToken
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .appScrollScreenPadding()
        }
        .appGroupedScreenBackground(palette)
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.large)
    }

    private func entryTile(
        title: String,
        systemImage: String,
        fillToken: PaletteToken,
        iconToken: PaletteToken
    ) -> some View {
        VStack(spacing: AppSpacing.control) {
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
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .appCard(palette: palette, radius: AppSpacing.largeCardRadius)
    }
}

private extension ActivityLogKind {
    var hubTitle: String {
        switch self {
        case .daily: "Water test"
        case .weekly: "Full water check"
        case .maintenance: "Service"
        case .usage: "Usage"
        }
    }
}
