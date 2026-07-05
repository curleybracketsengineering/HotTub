//
//  PadTabBar.swift
//  HotTub
//

import SwiftUI

/// Floating pill tab bar for iPad; widens on 11″ so every tab fits.
struct PadTabBar: View {
    @Binding var selection: AppTab
    let availableWidth: CGFloat

    @Environment(\.appPalette) private var palette

    private struct TabDescriptor: Identifiable {
        let tab: AppTab
        let title: String
        let systemImage: String
        var id: AppTab { tab }
    }

    private var tabs: [TabDescriptor] {
        [
            TabDescriptor(tab: .dashboard, title: "Home", systemImage: "house.fill"),
            TabDescriptor(tab: .history, title: "History", systemImage: "clock.arrow.circlepath"),
            TabDescriptor(tab: .charts, title: "Insights", systemImage: "chart.xyaxis.line"),
            TabDescriptor(tab: .setup, title: "Settings", systemImage: "gearshape.fill"),
        ]
    }

    private var pillWidth: CGFloat {
        PadContentLayout.tabBarPillWidth(for: availableWidth)
    }

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: PadContentLayout.tabBarItemSpacing) {
                ForEach(tabs) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, PadContentLayout.tabBarPillInnerPadding)
            .padding(.vertical, PadContentLayout.tabBarPillVerticalPadding)
            .frame(width: pillWidth)
            .background {
                Capsule(style: .continuous)
                    .fill(palette.color(.surfaceCard))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: PadContentLayout.tabBarShadowRadius,
                        y: PadContentLayout.tabBarShadowYOffset
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PadContentLayout.tabBarOuterHorizontalPadding)
        .padding(.top, PadContentLayout.tabBarTopPadding)
        .padding(.bottom, PadContentLayout.tabBarBottomPadding)
    }

    private func tabButton(_ tab: TabDescriptor) -> some View {
        let isSelected = selection == tab.tab
        let accent = palette.color(.accentBlue)

        return Button {
            selection = tab.tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: PadContentLayout.tabBarIconSize, height: PadContentLayout.tabBarIconSize)

                Text(tab.title)
                    .font(PadContentLayout.tabBarFont(for: availableWidth))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? accent : palette.color(.textPrimary))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PadContentLayout.tabBarItemHorizontalPadding)
            .padding(.vertical, PadContentLayout.tabBarItemVerticalPadding)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.14))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(tab.title)
    }
}
