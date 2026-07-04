//
//  HelpContentSanitizer.swift
//  HotTub
//
//  Single sanitizer guide; `focus` controls which section opens first.
//

import SwiftUI

struct HelpSanitizerContent: View {
    let isBromine: Bool
    var focus: SanitizerHelpFocus = .overview
    @Environment(\.appPalette) private var palette

    private var name: String { isBromine ? "Bromine" : "Chlorine" }
    private var nameLower: String { isBromine ? "bromine" : "chlorine" }

    private var headline: String {
        if isBromine {
            switch focus {
            case .total: return "Total Bromine Guide"
            case .combined: return "Bromine Guide"
            default: return "Bromine Help Guide"
            }
        }
        switch focus {
        case .free: return "Free Chlorine Guide"
        case .combined: return "Combined Chlorine Guide"
        case .total: return "Total Chlorine Guide"
        case .overview: return "Chlorine Help Guide"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headline)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(
                title: "\(name) – What it does",
                defaultExpanded: focus == .overview
            ) {
                HelpParagraph(
                    text: "\(name) is the primary sanitizer that kills bacteria, viruses, and algae in hot tubs.",
                    bold: true
                )
                if !isBromine && focus == .combined {
                    HelpParagraph(
                        text: "Combined and total chlorine are measured on the weekly check. Free chlorine is logged on the daily check.",
                        topPadding: 8
                    )
                }
            }

            HelpCollapsibleSection(
                title: isBromine ? "Bromine level" : "Free Chlorine (FC)",
                defaultExpanded: focus == .free || (focus == .overview && isBromine)
            ) {
                HelpParagraph(text: "What it is", bold: true)
                HelpParagraph(
                    text: isBromine
                        ? "Active bromine available to sanitize the water."
                        : "Chlorine available to sanitize. The most important chlorine value.",
                    topPadding: 4
                )
                HelpIdealRange(
                    label: "Ideal range",
                    value: isBromine ? "3–5 ppm" : "1–3 ppm"
                )
                HelpParagraph(text: "If too low", bold: true, topPadding: 12)
                HelpBullet(text: "Poor sanitation")
                HelpBullet(text: "Risk of bacteria growth")
                HelpBullet(text: "Cloudy or smelly water")
                HelpParagraph(text: "If too high", bold: true, topPadding: 12)
                HelpBullet(text: "Skin and eye irritation")
                HelpBullet(text: "Strong \(nameLower) smell")
                HelpBullet(text: "Faster wear on covers and plastics")
            }

            if !isBromine {
                HelpCollapsibleSection(
                    title: "Combined Chlorine (CC)",
                    defaultExpanded: focus == .combined
                ) {
                    HelpParagraph(text: "What it is", bold: true)
                    HelpParagraph(text: "Chlorine that has already reacted with sweat, oils, or other contaminants.", topPadding: 4)
                    HelpParagraph(text: "Also called chloramines — it is not available to sanitize.", topPadding: 4)
                    HelpIdealRange(label: "Ideal range", value: "0–0.5 ppm")
                    HelpParagraph(text: "How it relates to total chlorine", bold: true, topPadding: 12)
                    HelpParagraph(
                        text: "Total Chlorine = Free Chlorine + Combined Chlorine. Low combined chlorine usually means your free chlorine is doing most of the work.",
                        topPadding: 4
                    )
                    HelpParagraph(text: "Signs of high combined chlorine", bold: true, topPadding: 12)
                    HelpBullet(text: "\"Chlorine\" smell (often chloramines, not free chlorine)")
                    HelpBullet(text: "Eye irritation")
                    HelpBullet(text: "Water smells musty or unpleasant")
                    HelpParagraph(text: "Typical approach when CC is high", bold: true, topPadding: 12)
                    HelpBullet(text: "Shock the spa (briefly raise free chlorine to about 8–10 ppm)")
                    HelpBullet(text: "Leave the cover open during shocking")
                    HelpBullet(text: "Retest free, combined, and total after levels settle")
                }

                HelpCollapsibleSection(
                    title: "Total Chlorine (TC)",
                    defaultExpanded: focus == .total
                ) {
                    HelpParagraph(text: "What it is", bold: true)
                    HelpParagraph(
                        text: "All chlorine in the water: sanitizer still working (free) plus chlorine already used up on contaminants (combined).",
                        topPadding: 4
                    )
                    HelpIdealRange(label: "Typical total range", value: "3–5 ppm")
                    HelpInfoBox {
                        Text("Key relationship:\nCombined Chlorine = Total Chlorine − Free Chlorine")
                            .font(.subheadline)
                            .foregroundStyle(palette.color(.textSecondary))
                    }
                    HelpParagraph(text: "Example", bold: true, topPadding: 12)
                    HelpBullet(text: "Total Chlorine = 4.4 ppm")
                    HelpBullet(text: "Free Chlorine = 4.3 ppm (from your daily log)")
                    HelpBullet(text: "Combined Chlorine = 0.1 ppm ✓")
                    HelpParagraph(text: "How to use this reading", bold: true, topPadding: 12)
                    HelpBullet(text: "Log total chlorine on the weekly check alongside combined chlorine")
                    HelpBullet(text: "Compare with your latest free chlorine from the daily log")
                    HelpBullet(text: "If total is fine but combined is high, shock and retest")
                }
            } else {
                HelpCollapsibleSection(
                    title: "Total bromine",
                    defaultExpanded: focus == .total || focus == .combined
                ) {
                    HelpParagraph(text: "What it is", bold: true)
                    HelpParagraph(
                        text: "Total bromine in the water (active sanitizer plus bromine that has been used).",
                        topPadding: 4
                    )
                    HelpIdealRange(label: "Ideal range", value: "3–5 ppm")
                }
            }

            HelpCollapsibleSection(
                title: "Common Mistakes to Avoid",
                defaultExpanded: focus == .overview || focus == .free
            ) {
                HelpBullet(text: "Ignoring pH when \(nameLower) won't hold")
                if !isBromine {
                    HelpBullet(text: "Confusing \"chlorine smell\" with adequate free chlorine")
                    HelpBullet(text: "Only checking total chlorine and ignoring combined chlorine")
                }
                HelpBullet(text: "Shocking without checking combined chlorine (chlorine systems)")
                HelpBullet(text: "Adding large doses without retesting")
            }

            if focus == .overview || focus == .free {
                HelpInfoBox {
                    Text(
                        isBromine
                            ? "pH affects how well bromine works. For pH guidance, use the help on the pH field in the daily log. For copper, use the help on the weekly check."
                            : "Log free chlorine on the daily check; log combined and total chlorine on the weekly check. For pH, use the help on the daily log."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpEducationalDisclaimer()
        }
    }
}
