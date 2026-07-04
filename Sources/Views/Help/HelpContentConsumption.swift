//
//  HelpContentConsumption.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/ConsumptionContent.jsx`.
//

import SwiftUI

struct HelpConsumptionContent: View {
    let isBromine: Bool
    let isMetric: Bool
    @Environment(\.appPalette) private var palette

    private var weightUnit: String { isMetric ? "g" : "oz" }
    private var sanitizerName: String { isBromine ? "Bromine" : "Chlorine" }
    private var sanitizerLower: String { sanitizerName.lowercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sanitizer Consumption Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpParagraph(
                text: "The Sanitizer Consumption card shows how quickly your hot tub is using \(sanitizerLower), helping you predict when to add more chemicals.",
                bold: true
            )

            HelpCollapsibleSection(title: "How It's Calculated", defaultExpanded: true) {
                HelpParagraph(text: "The system tracks the natural decay of \(sanitizerLower) between daily log entries:")
                HelpBullet(text: "Measures \(sanitizerLower) levels at two different times")
                HelpBullet(text: "Calculates the drop in ppm (parts per million)")
                HelpBullet(text: "Factors in any \(sanitizerLower) you added between readings")
                HelpBullet(text: "Converts to daily consumption rate in \(weightUnit)/day")
                HelpInfoBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What You Need:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.color(.textPrimary))
                        HelpBullet(text: "At least 2 daily logs with \(sanitizerLower) readings")
                        HelpBullet(text: "Readings taken on different days")
                        HelpBullet(text: "Accurate recording of any \(sanitizerLower) added")
                    }
                }
            }

            HelpCollapsibleSection(title: "Understanding the Numbers") {
                HelpParagraph(text: "Current Rate", bold: true)
                HelpParagraph(
                    text: "Shows consumption between your last two daily logs. This is the most recent data point.",
                    topPadding: 4
                )
                HelpParagraph(text: "7-day Average", bold: true, topPadding: 12)
                HelpParagraph(
                    text: "Averages all consumption rates from the past week, giving you a more stable trend.",
                    topPadding: 4
                )
                HelpParagraph(text: "Trend Indicator", bold: true, topPadding: 12)
                HelpParagraph(text: "Compares current rate to the 7-day average:", topPadding: 4)
                trendRow(
                    symbol: "↑",
                    color: palette.color(.accentRed),
                    label: "Red arrow:",
                    detail: "Using more \(sanitizerLower) than usual (5%+ increase)"
                )
                trendRow(
                    symbol: "↓",
                    color: palette.color(.accentGreen),
                    label: "Green arrow:",
                    detail: "Using less \(sanitizerLower) than usual (5%+ decrease)"
                )
                trendRow(
                    symbol: "—",
                    color: palette.color(.textTertiary),
                    label: "Gray dash:",
                    detail: "Stable consumption (within 5%)"
                )
            }

            HelpCollapsibleSection(title: "Smart Exclusions") {
                HelpParagraph(
                    text: "The calculator automatically excludes periods where chlorine-based shock was applied:"
                )
                HelpBullet(text: "Cal-Hypo, Dichlor, Lithium Hypo shocks add \(sanitizerLower)")
                HelpBullet(text: "This would make consumption look artificially low")
                HelpBullet(text: "Non-chlorine shock (MPS) is safe and won't be excluded")
                HelpWarningBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("If you see \"Excluded\":")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.color(.statusWarningText))
                        Text(
                            "A chlorine-based shock was applied between daily logs, so that period can't be used for accurate consumption tracking."
                        )
                        .font(.subheadline)
                        .foregroundStyle(palette.color(.textSecondary))
                    }
                }
            }

            HelpCollapsibleSection(title: "Usage Tips") {
                HelpBullet(text: "Log daily for best accuracy")
                HelpBullet(text: "Record \(sanitizerLower) additions immediately")
                HelpBullet(text: "Higher usage = more hot tub use or warmer water")
                HelpBullet(text: "Lower usage = less activity or cooler water")
                HelpBullet(text: "Use trends to predict when to buy more chemicals")
            }

            HelpEducationalDisclaimerShort(
                text: "This information is for educational purposes only. Consumption calculations are estimates based on your logged data. Always test your water and follow manufacturer guidelines for chemical additions."
            )
        }
    }

    @ViewBuilder
    private func trendRow(symbol: String, color: Color, label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
