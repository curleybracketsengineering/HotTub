//
//  MainTabView.swift
//  HotTub
//

import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case history
    case charts
    case setup
}

struct MainTabView: View {
    @Environment(\.appPalette) private var palette

    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        GeometryReader { geometry in
            let usePadLayout = AppLayout.usePadLayout(availableWidth: geometry.size.width)
            let isLandscape = AppLayout.isLandscape(size: geometry.size)

            Group {
                if usePadLayout {
                    padTabRoot(availableWidth: geometry.size.width)
                } else {
                    phoneTabRoot
                }
            }
            .environment(\.usePadLayout, usePadLayout)
            .environment(\.isLandscape, isLandscape)
        }
    }

    // MARK: - iPad

    private func padTabRoot(availableWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            PadTabBar(selection: $selectedTab, availableWidth: availableWidth)

            padTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.color(.backgroundSecondary).ignoresSafeArea())
    }

    @ViewBuilder
    private var padTabContent: some View {
        switch selectedTab {
        case .dashboard:
            NavigationStack {
                DashboardView()
            }
        case .history:
            HistoryView()
        case .charts:
            NavigationStack {
                ChartsScreenView()
            }
        case .setup:
            NavigationStack {
                SetupView()
            }
        }
    }

    // MARK: - iPhone

    private var phoneTabRoot: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tag(AppTab.dashboard)
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            NavigationStack {
                HistoryView()
            }
            .tag(AppTab.history)
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                ChartsScreenView()
            }
            .tag(AppTab.charts)
            .tabItem {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                SetupView()
            }
            .tag(AppTab.setup)
            .tabItem {
                Label("Setup", systemImage: "gearshape.fill")
            }
        }
        .tint(palette.color(.accentBlue))
    }
}
