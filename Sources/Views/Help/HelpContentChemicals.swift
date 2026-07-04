//
//  HelpContentChemicals.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/ChemicalsAddedContent.jsx`.
//

import SwiftUI

struct HelpChemicalsAddedContent: View {
    let isBromine: Bool
    let isMetric: Bool
    @Environment(\.appPalette) private var palette

    private var weightUnit: String { isMetric ? "g" : "oz" }
    private var sanitizerWord: String { isBromine ? "Bromine" : "Chlorine" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chemical Addition Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(title: "General Safety Rules", defaultExpanded: true) {
                HelpWarningBox {
                    Text("NEVER mix chemicals together before adding to water")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.color(.statusWarningText))
                }
                HelpBullet(text: "Add chemicals one at a time")
                HelpBullet(text: "Wait at least 30 minutes between additions")
                HelpBullet(text: "Always add chemicals to water, never water to chemicals")
                HelpBullet(text: "Run circulation pump when adding chemicals")
                HelpBullet(text: "Keep chemicals in original containers")
                HelpBullet(text: "Store in a cool, dry place away from sunlight")
            }

            HelpCollapsibleSection(title: "General Dosing Information (Educational)") {
                HelpParagraph(text: "Basic principle", bold: true)
                HelpInfoBox {
                    Text("Start with small doses and retest. It's easier to add more than to dilute.")
                        .font(.subheadline)
                        .foregroundStyle(palette.color(.textSecondary))
                }
                HelpParagraph(
                    text: "Typical starting doses (adjust based on test results and product labels):",
                    bold: true,
                    topPadding: 12
                )
                HelpBullet(
                    text: "pH adjustment: 10-20\(weightUnit) per adjustment (refer to manufacturer guidance)"
                )
                HelpBullet(
                    text: "\(sanitizerWord): Follow manufacturer's directions for your tub size"
                )
                HelpBullet(text: "Always measure based on your specific tub capacity")
            }

            HelpCollapsibleSection(title: "Typical Timing Considerations") {
                HelpBullet(text: "Best time: Evening, when tub won't be used for several hours")
                HelpBullet(text: "Common practice is to avoid adding chemicals just before use")
                HelpBullet(
                    text: "Commonly, users wait at least 20-30 minutes after adding before entering"
                )
                HelpBullet(text: "Test water before each use")
            }

            HelpCollapsibleSection(title: "Typical Order of Chemical Addition") {
                HelpParagraph(text: "If multiple adjustments are needed:", bold: true)
                HelpBullet(text: "1. Adjust Alkalinity first (if needed)")
                HelpBullet(text: "2. Then adjust pH")
                HelpBullet(text: "3. Then add sanitizer (\(sanitizerWord.lowercased()))")
                HelpBullet(text: "4. Wait 30+ minutes between each step")
            }

            HelpCollapsibleSection(title: "Common Mistakes") {
                HelpBullet(text: "Adding too much at once")
                HelpBullet(text: "Not waiting between additions")
                HelpBullet(text: "Adding chemicals with pump off")
                HelpBullet(text: "Not retesting after adjustments")
                HelpBullet(text: "Using expired chemicals")
            }

            HelpEducationalDisclaimer()
        }
    }
}
