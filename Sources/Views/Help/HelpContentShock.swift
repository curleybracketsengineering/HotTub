//
//  HelpContentShock.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/ShockContent.jsx`.
//

import SwiftUI

struct HelpShockContent: View {
    let isBromine: Bool
    let isMetric: Bool
    @Environment(\.appPalette) private var palette

    private var weightUnit: String { isMetric ? "g" : "oz" }
    private var sanitizerWord: String { isBromine ? "bromine" : "chlorine" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shock Treatment Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(title: "What is Shocking?", defaultExpanded: true) {
                HelpParagraph(
                    text: "Shocking is adding a large dose of oxidizer to break down contaminants and restore water clarity.",
                    bold: true
                )
                HelpParagraph(
                    text: "It eliminates chloramines/bromamines, organic waste, and bacteria that regular sanitizing may miss.",
                    topPadding: 8
                )
            }

            HelpCollapsibleSection(title: "Common Scenarios for Shocking") {
                HelpParagraph(text: "Weekly maintenance", bold: true)
                HelpBullet(text: "Common practice is at least once per week")
                HelpBullet(text: "More often with heavy use")
                HelpParagraph(text: "After heavy use", bold: true, topPadding: 12)
                HelpBullet(text: "After a party or multiple users")
                HelpBullet(text: "Following extended soaking sessions")
                HelpParagraph(text: "When water quality declines", bold: true, topPadding: 12)
                HelpBullet(text: "Cloudy or dull water")
                HelpBullet(text: "Strong chemical smell")
                HelpBullet(text: "Foaming or skin irritation")
                HelpBullet(text: "Combined \(sanitizerWord) above 0.5 ppm")
            }

            HelpCollapsibleSection(title: "Typical Shock Process (For Reference)") {
                HelpParagraph(text: "Common step-by-step approach", bold: true)
                HelpBullet(text: "1. Test and balance pH to 7.2-7.6 first")
                HelpBullet(text: "2. Remove cover and turn on circulation")
                HelpBullet(text: "3. Add shock dose based on tub size (follow product instructions)")
                HelpBullet(text: "4. Run jets/circulation for 15-20 minutes")
                HelpBullet(text: "5. Leave cover OFF for at least 20 minutes")
                HelpBullet(text: "6. Test water before re-entering")
                HelpWarningBox {
                    Text(
                        "Common practice is NOT to enter the tub until \(sanitizerWord) levels return to safe range (under 5 ppm for chlorine, under 6 ppm for bromine). Consult product labels for specific guidance."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.statusWarningText))
                }
            }

            HelpCollapsibleSection(title: "Typical Shock Dosage (Educational)") {
                HelpInfoBox {
                    Text(
                        "Dosage varies by product. Common guideline: 35-50\(weightUnit) per 1000L (or 2-3 oz per 500 gallons). Always follow manufacturer's instructions."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
                HelpBullet(text: "Consult product instructions for your specific tub size")
                HelpBullet(text: "Use measuring cup or scoop for accuracy")
                HelpBullet(text: "Never mix shock products together")
            }

            HelpCollapsibleSection(title: "Shock Types") {
                HelpParagraph(text: "Chlorine-based shock", bold: true)
                HelpBullet(text: "Most common and effective")
                HelpBullet(text: "Temporarily raises \(sanitizerWord) to 8-10 ppm")
                HelpBullet(text: "Fast-acting oxidation")
                HelpParagraph(text: "Non-chlorine shock (MPS)", bold: true, topPadding: 12)
                HelpBullet(text: "Gentler alternative")
                HelpBullet(text: "Can use tub sooner (typically 15-30 minutes)")
                HelpBullet(text: "Less effective for heavy contamination")
                HelpBullet(text: "May require chlorine boost afterward")
            }

            HelpCollapsibleSection(title: "Safety & Best Practices") {
                HelpWarningBox {
                    Text(
                        "Never shock with people in the tub. Always add shock to water, never water to shock."
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.color(.statusWarningText))
                }
                HelpBullet(text: "Common practice is to shock in the evening when tub won't be used")
                HelpBullet(text: "Keep shock chemicals dry and sealed")
                HelpBullet(text: "Avoid shocking if copper is high (may cause staining)")
                HelpBullet(text: "Leave cover open to allow gases to escape")
                HelpBullet(text: "Test water chemistry before and after")
            }

            HelpCollapsibleSection(title: "Common Mistakes to Avoid") {
                HelpBullet(text: "Shocking with the cover on (traps gases)")
                HelpBullet(text: "Shocking without balancing pH first")
                HelpBullet(text: "Adding too much shock at once")
                HelpBullet(text: "Not running circulation during treatment")
                HelpBullet(text: "Entering tub before levels normalize")
                HelpBullet(text: "Mixing different shock products")
            }

            HelpEducationalDisclaimer()
        }
    }
}
