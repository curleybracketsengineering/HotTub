//
//  MainTabView.swift
//  HotTub
//

import SwiftUI

struct MainTabView: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                ChartsScreenView()
            }
            .tabItem {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                SetupView()
            }
            .tabItem {
                Label("Setup", systemImage: "gearshape.fill")
            }
        }
        .tint(palette.color(.accentBlue))
    }
}
