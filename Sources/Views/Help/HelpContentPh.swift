//
//  HelpContentPh.swift
//  HotTub
//
//  Single pH guide; `focus` controls which section opens first.
//

import SwiftUI

struct HelpPhContent: View {
    var focus: PhHelpFocus = .overview
    @Environment(\.appPalette) private var palette

    private var headline: String {
        switch focus {
        case .overview: return "pH Help Guide"
        case .down: return "pH Down Guide"
        case .up: return "pH Up Guide"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headline)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(title: "pH – What it is", defaultExpanded: focus == .overview) {
                HelpParagraph(text: "pH measures how acidic or alkaline the water is.", bold: true)
                HelpParagraph(text: "It affects comfort, sanitizer efficiency, and equipment life.", topPadding: 8)
                HelpIdealRange(label: "Ideal pH range", value: "7.2 – 7.6")
                HelpBullet(text: "Low pH = acidic")
                HelpBullet(text: "High pH = alkaline")
            }

            HelpCollapsibleSection(title: "pH Down (Lower pH)", defaultExpanded: focus == .down) {
                HelpParagraph(text: "Common scenarios", bold: true)
                HelpBullet(text: "pH is above 7.6")
                HelpBullet(text: "Water looks dull or cloudy")
                HelpBullet(text: "Scale forming")
                HelpBullet(text: "Chlorine/bromine not working efficiently")
                HelpParagraph(text: "Typical process (for reference)", bold: true, topPadding: 12)
                HelpBullet(text: "Commonly, users add a small dose of pH Down")
                HelpBullet(text: "Run circulation with air OFF")
                HelpBullet(text: "Wait 30–60 minutes")
                HelpBullet(text: "Retest and repeat if needed")
                HelpInfoBox {
                    Text(
                        "pH Down will also slightly lower alkalinity. Common practice is to lower pH gradually. Consult product labels for specific instructions."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "pH Up (Raise pH)", defaultExpanded: focus == .up) {
                HelpParagraph(text: "Common scenarios", bold: true)
                HelpBullet(text: "pH is below 7.2")
                HelpBullet(text: "Water feels sharp or irritating")
                HelpBullet(text: "Corrosion risk to metal parts")
                HelpParagraph(text: "Typical process (for reference)", bold: true, topPadding: 12)
                HelpBullet(text: "Commonly, users add a small dose of pH Up")
                HelpBullet(text: "Circulate water for 20–30 minutes")
                HelpBullet(text: "Retest before adding more")
                HelpInfoBox {
                    Text(
                        "pH Up can also raise alkalinity. If total alkalinity is out of range, fix that first (see the alkalinity guide on weekly check), then fine-tune pH."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "Common Mistakes to Avoid", defaultExpanded: focus == .overview) {
                HelpBullet(text: "Chasing \"perfect\" pH in one go")
                HelpBullet(text: "Adding pH Up and Down on the same day")
                HelpBullet(text: "Running air jets while lowering pH")
                HelpBullet(text: "Adjusting pH when total alkalinity is far out of range")
            }

            if focus == .overview {
                HelpInfoBox {
                    Text(
                        "Total alkalinity buffers pH. For alkalinity testing, raising/lowering TA, and adjustment order, open the help on Total alkalinity in the weekly check."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpEducationalDisclaimer()
        }
    }
}
