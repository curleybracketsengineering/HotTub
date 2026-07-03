//
//  SetupDisclaimerView.swift
//  HotTub Buddy
//

import SwiftUI

struct SetupDisclaimerView: View {
    let isBromine: Bool
    let isMetric: Bool

    @Environment(\.appPalette) private var palette
    @State private var showDisclaimer = false
    @State private var showChemicalSafety = false

    var body: some View {
        VStack(spacing: 0) {
            AppSettingsNavigationRow(label: "Important safety information") {
                showDisclaimer = true
            }

            AppSettingsDivider()

            AppSettingsNavigationRow(label: "Chemical safety") {
                showChemicalSafety = true
            }
        }
        .appCard(palette: palette, padding: 0)
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerSheetView()
        }
        .sheet(isPresented: $showChemicalSafety) {
            HelpSheetView(
                request: HelpSheetRequest(topic: .chemicalsAdded),
                isBromine: isBromine,
                isMetric: isMetric
            )
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.control) {
            AppSectionHeader(title: "Safety information")
            SetupDisclaimerView(isBromine: false, isMetric: true)
        }
        .appScrollScreenPadding()
    }
    .appPalette(.light)
}
