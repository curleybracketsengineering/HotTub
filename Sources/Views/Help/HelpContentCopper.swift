//
//  HelpContentCopper.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/CopperContent.jsx`.
//

import SwiftUI

struct HelpCopperContent: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Copper (Cu) Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(title: "What is Copper?", defaultExpanded: true) {
                HelpParagraph(
                    text: "Copper is a metal that can dissolve into your hot tub water from various sources.",
                    bold: true
                )
                HelpParagraph(
                    text: "While small amounts are usually harmless, elevated copper levels can cause staining, discoloration, and equipment damage.",
                    topPadding: 8
                )
                HelpIdealRange(label: "Ideal Copper range", value: "0.0 – 0.5 ppm")
                HelpParagraph(
                    text: "Ideally, copper should be as close to 0.0 ppm as possible.",
                    topPadding: 8
                )
            }

            HelpCollapsibleSection(title: "Why Copper Matters") {
                HelpParagraph(text: "Copper affects:", bold: true)
                HelpBullet(text: "Water clarity and appearance")
                HelpBullet(text: "Potential staining on surfaces")
                HelpBullet(text: "Hair and skin discoloration")
                HelpBullet(text: "Equipment longevity and performance")
                HelpParagraph(text: "Health concerns", bold: true, topPadding: 12)
                HelpParagraph(
                    text: "While not immediately dangerous at typical hot tub levels, prolonged exposure to high copper can cause skin irritation and digestive issues if water is accidentally swallowed.",
                    topPadding: 4
                )
            }

            HelpCollapsibleSection(title: "Sources of Copper") {
                HelpParagraph(text: "Common sources include:", bold: true)
                HelpBullet(text: "Copper-based algaecides (most common source)")
                HelpBullet(text: "Corroded copper pipes or heat exchangers")
                HelpBullet(text: "Fill water (especially from wells with copper plumbing)")
                HelpBullet(text: "Low pH causing corrosion of copper components")
                HelpBullet(text: "Old or damaged heater elements")
                HelpInfoBox {
                    Text(
                        "Prevention tip: Test your fill water for copper before filling your hot tub, especially if you have copper plumbing or well water."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "High Copper Problems") {
                HelpParagraph(text: "Signs of high copper levels:", bold: true)
                HelpBullet(text: "Green, blue, or turquoise water tint")
                HelpBullet(text: "Blue-green staining on surfaces or equipment")
                HelpBullet(text: "Green tint in blonde or light-colored hair")
                HelpBullet(text: "Metallic taste in water")
                HelpBullet(text: "Increased equipment corrosion")
                HelpWarningBox {
                    Text(
                        "Copper stains can be permanent if not treated quickly. Address high copper levels as soon as they're detected."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.statusWarningText))
                }
            }

            HelpCollapsibleSection(title: "Typical Approaches to Lower Copper (Educational)") {
                HelpParagraph(text: "If copper is above 0.5 ppm:", bold: true)
                HelpParagraph(text: "1. Use a Metal Sequestrant (Common Approach)", bold: true, topPadding: 12)
                HelpBullet(text: "Add a metal sequestrant or chelating agent")
                HelpBullet(text: "This binds to copper and keeps it in suspension")
                HelpBullet(text: "Follow product instructions carefully")
                HelpBullet(text: "Run filtration continuously for 24–48 hours")
                HelpParagraph(text: "2. Partial Water Changes (Common Approach)", bold: true, topPadding: 12)
                HelpBullet(text: "Drain 25–50% of water and refill with fresh water")
                HelpBullet(text: "Test source water first to ensure it's low in copper")
                HelpBullet(text: "May need to repeat over several weeks")
                HelpParagraph(text: "3. Stop Adding Copper Sources", bold: true, topPadding: 12)
                HelpBullet(text: "Discontinue copper-based algaecides immediately")
                HelpBullet(text: "Use non-copper alternatives instead")
                HelpInfoBox {
                    Text(
                        "For severe copper problems (above 1.0 ppm), consider consulting a spa professional or complete drain and refill with tested low-copper water."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "Prevention Tips") {
                HelpParagraph(text: "Keep copper levels low by:", bold: true)
                HelpBullet(text: "Avoiding copper-based algaecides entirely")
                HelpBullet(text: "Testing source water before filling")
                HelpBullet(text: "Maintaining proper pH (7.2–7.6) to prevent corrosion")
                HelpBullet(text: "Using a pre-filter when filling from copper pipes")
                HelpBullet(text: "Regular testing (weekly or bi-weekly)")
                HelpBullet(text: "Inspecting heaters and heat exchangers for corrosion")
                HelpInfoBox {
                    Text(
                        "Hot tubs with good pH balance and proper sanitizer rarely have copper issues, unless copper-based chemicals are added."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "When to Test Copper") {
                HelpParagraph(text: "Test copper levels:", bold: true)
                HelpBullet(text: "Weekly as part of routine maintenance")
                HelpBullet(text: "After filling or refilling the hot tub")
                HelpBullet(text: "If you notice green/blue water tint")
                HelpBullet(text: "If you see staining on surfaces")
                HelpBullet(text: "After using any copper-based products")
                HelpBullet(text: "If pH has been low for extended periods")
            }

            HelpCollapsibleSection(title: "Common Mistakes to Avoid") {
                HelpBullet(text: "Using copper-based algaecides in hot tubs")
                HelpBullet(text: "Ignoring low pH (which corrodes copper components)")
                HelpBullet(text: "Not testing source water before filling")
                HelpBullet(text: "Waiting too long to treat high copper levels")
                HelpBullet(text: "Shocking water when copper is high (can cause staining)")
            }

            HelpEducationalDisclaimer()
        }
    }
}
