//
//  HelpSheetView.swift
//  HotTub
//
//  Sheet host migrated from React `HelpModal.jsx`.
//

import SwiftUI

struct HelpSheetView: View {
    let request: HelpSheetRequest
    var isBromine: Bool
    var isMetric: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette

    private var navigationTitle: String {
        switch request.topic {
        case .ph:
            switch request.phFocus {
            case .overview: return "pH Guide"
            case .down: return "pH Down Guide"
            case .up: return "pH Up Guide"
            }
        case .sanitizer:
            if isBromine {
                switch request.sanitizerFocus {
                case .total, .combined: return "Total Bromine Guide"
                default: return "Bromine Guide"
                }
            }
            switch request.sanitizerFocus {
            case .free: return "Free Chlorine Guide"
            case .combined: return "Combined Chlorine Guide"
            case .total: return "Total Chlorine Guide"
            case .overview: return "Chlorine Guide"
            }
        default:
            return request.topic.screenTitle
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                HelpTopicRouter(request: request, isBromine: isBromine, isMetric: isMetric)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
            .background(palette.color(.backgroundSecondary))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct HelpTopicRouter: View {
    let request: HelpSheetRequest
    let isBromine: Bool
    let isMetric: Bool

    var body: some View {
        switch request.topic {
        case .ph:
            HelpPhContent(focus: request.phFocus)
        case .sanitizer:
            HelpSanitizerContent(isBromine: isBromine, focus: request.sanitizerFocus)
        case .copper:
            HelpCopperContent()
        case .alkalinity:
            HelpAlkalinityContent()
        case .temperature:
            HelpTemperatureContent()
        case .chemicalsAdded:
            HelpChemicalsAddedContent(isBromine: isBromine, isMetric: isMetric)
        case .shock:
            HelpShockContent(isBromine: isBromine, isMetric: isMetric)
        case .consumption:
            HelpConsumptionContent(isBromine: isBromine, isMetric: isMetric)
        case .general:
            HelpDefaultContent()
        }
    }
}
