//
//  ActivityLogKind.swift
//  HotTub Buddy
//

import SwiftUI

/// Shared icons and accent tokens for log entry types (Activity hub, History, Dashboard).
enum ActivityLogKind: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case maintenance
    case usage

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .daily: "drop.fill"
        case .weekly: "calendar.badge.checkmark"
        case .maintenance: "wrench.fill"
        case .usage: "timer"
        }
    }

    var fillToken: PaletteToken {
        switch self {
        case .daily: .tagBlueFill
        case .weekly: .tagGreenFill
        case .maintenance: .tagOrangeFill
        case .usage: .tagPinkFill
        }
    }

    var iconToken: PaletteToken {
        switch self {
        case .daily: .accentBlue
        case .weekly: .accentGreen
        case .maintenance: .accentOrange
        case .usage: .accentPink
        }
    }

    @ViewBuilder
    var formDestination: some View {
        switch self {
        case .daily:
            DailyLogFormView()
        case .weekly:
            WeeklyLogFormView()
        case .maintenance:
            MaintenanceLogFormView()
        case .usage:
            UsageLogFormView()
        }
    }
}

extension HistoryRow {
    var kind: ActivityLogKind {
        switch self {
        case .daily: .daily
        case .weekly: .weekly
        case .maintenance: .maintenance
        case .usage: .usage
        }
    }
}
