//
//  HelpContentAlkalinity.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/AlkalinityContent.jsx`.
//

import SwiftUI

struct HelpAlkalinityContent: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Total Alkalinity Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(title: "What is Total Alkalinity?", defaultExpanded: true) {
                HelpParagraph(
                    text: "Total Alkalinity (TA) is a measure of your water's ability to resist changes in pH.",
                    bold: true
                )
                HelpParagraph(
                    text: "Think of it as a pH buffer or shock absorber. When TA is in the ideal range, your pH stays stable. When it's too low, pH swings wildly. When it's too high, pH becomes difficult to adjust.",
                    topPadding: 8
                )
                HelpIdealRange(label: "Ideal Total Alkalinity range", value: "80 – 120 ppm")
                HelpParagraph(text: "Most hot tubs perform best around 100 ppm.", topPadding: 8)
            }

            HelpCollapsibleSection(title: "Why Alkalinity Matters") {
                HelpParagraph(text: "Total Alkalinity affects:", bold: true)
                HelpBullet(text: "pH stability")
                HelpBullet(text: "Sanitizer effectiveness (chlorine/bromine)")
                HelpBullet(text: "Water clarity")
                HelpBullet(text: "Equipment corrosion rates")
                HelpBullet(text: "Bather comfort")
                HelpParagraph(text: "The pH-Alkalinity relationship", bold: true, topPadding: 12)
                HelpParagraph(
                    text: "TA and pH are closely linked. Adjusting one often affects the other. Always adjust Total Alkalinity FIRST, then fine-tune pH.",
                    topPadding: 4
                )
            }

            HelpCollapsibleSection(title: "Low Alkalinity Problems") {
                HelpParagraph(text: "When TA is below 80 ppm:", bold: true)
                HelpBullet(text: "pH becomes unstable and swings easily")
                HelpBullet(text: "Water may become corrosive to equipment")
                HelpBullet(text: "Eye and skin irritation increases")
                HelpBullet(text: "Sanitizer efficiency decreases")
                HelpBullet(text: "Staining may occur")
                HelpWarningBox {
                    Text(
                        "Low alkalinity can cause rapid pH drops, making water acidic and damaging to your hot tub components."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.statusWarningText))
                }
            }

            HelpCollapsibleSection(title: "High Alkalinity Problems") {
                HelpParagraph(text: "When TA is above 120 ppm:", bold: true)
                HelpBullet(text: "pH becomes difficult to lower")
                HelpBullet(text: "Water may become cloudy or hazy")
                HelpBullet(text: "Scale formation increases")
                HelpBullet(text: "Sanitizer effectiveness decreases")
                HelpBullet(text: "Equipment and surfaces may develop calcium deposits")
                HelpInfoBox {
                    Text(
                        "High alkalinity often causes pH to drift upward constantly, requiring frequent pH Down additions."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "Typical Process to Raise Alkalinity (Educational)") {
                HelpParagraph(text: "If Total Alkalinity is below 80 ppm:", bold: true)
                HelpParagraph(text: "Common approach using Alkalinity Up (Sodium Bicarbonate)", bold: true, topPadding: 12)
                HelpBullet(text: "Add Alkalinity Increaser/Alkalinity Up")
                HelpBullet(text: "Also called \"Sodium Bicarbonate\" or \"Baking Soda\"")
                HelpBullet(text: "Follow product instructions for dosage")
                HelpBullet(text: "Broadcast evenly across the water surface")
                HelpBullet(text: "Run jets for 15-30 minutes to circulate")
                HelpBullet(text: "Wait 2-4 hours before retesting")
                HelpParagraph(text: "Typical dosage reference (for 400-gallon hot tub):", bold: true, topPadding: 12)
                HelpBullet(text: "To raise TA by 10 ppm: ~40g (1.5 oz)")
                HelpBullet(text: "To raise TA by 20 ppm: ~80g (3 oz)")
                HelpBullet(text: "To raise TA by 30 ppm: ~120g (4.5 oz)")
                HelpInfoBox {
                    Text(
                        "Always check your product label for specific dosing instructions based on your hot tub's water volume."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "Typical Process to Lower Alkalinity (Educational)") {
                HelpParagraph(text: "If Total Alkalinity is above 120 ppm:", bold: true)
                HelpParagraph(text: "Common approach using pH Down (with aeration method)", bold: true, topPadding: 12)
                HelpBullet(text: "Add pH Down (Sodium Bisulfate or Muriatic Acid)")
                HelpBullet(text: "This will lower BOTH pH and TA")
                HelpBullet(text: "Add slowly in small doses over several days")
                HelpBullet(text: "Run jets and aerators to increase aeration")
                HelpBullet(text: "Aeration raises pH while keeping TA lower")
                HelpBullet(text: "Retest after 4-6 hours and adjust as needed")
                HelpWarningBox {
                    Text(
                        "There is no \"Alkalinity Down\" product. Lowering alkalinity is managed by carefully using pH Down and controlling aeration. Consult a spa professional if unsure."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.statusWarningText))
                }
                HelpParagraph(text: "The aeration technique:", bold: true, topPadding: 12)
                HelpBullet(text: "1. Lower both pH and TA with pH Down")
                HelpBullet(text: "2. Run jets/aerators to raise pH back up")
                HelpBullet(text: "3. Repeat until TA reaches ideal range")
                HelpBullet(text: "4. Fine-tune pH separately once TA is correct")
            }

            HelpCollapsibleSection(title: "Testing & Adjustment Tips") {
                HelpParagraph(text: "Best practices:", bold: true)
                HelpBullet(text: "Test TA weekly as part of routine maintenance")
                HelpBullet(text: "Always adjust TA BEFORE adjusting pH")
                HelpBullet(text: "Make small adjustments and retest before adding more")
                HelpBullet(text: "Wait at least 4 hours between tests for accurate readings")
                HelpBullet(text: "Keep detailed logs of adjustments and results")
                HelpInfoBox {
                    Text("Stable alkalinity means less frequent chemical adjustments and more enjoyable soaking time!")
                        .font(.subheadline)
                        .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpCollapsibleSection(title: "Common Mistakes to Avoid") {
                HelpBullet(text: "Adjusting pH before fixing alkalinity")
                HelpBullet(text: "Adding too much Alkalinity Up at once")
                HelpBullet(text: "Expecting instant results (wait 4+ hours)")
                HelpBullet(text: "Ignoring TA when pH keeps drifting")
                HelpBullet(text: "Using pH Up/Down without checking TA first")
                HelpBullet(text: "Looking for \"Alkalinity Down\" (it doesn't exist!)")
            }

            HelpCollapsibleSection(title: "Alkalinity vs pH: What's the Difference?") {
                HelpParagraph(text: "pH measures acidity/basicity", bold: true)
                HelpParagraph(
                    text: "pH tells you how acidic or basic your water is right now (scale 0-14).",
                    topPadding: 4
                )
                HelpParagraph(text: "Total Alkalinity measures buffering capacity", bold: true, topPadding: 12)
                HelpParagraph(
                    text: "TA tells you how well your water resists pH changes (measured in ppm).",
                    topPadding: 4
                )
                HelpInfoBox {
                    Text(
                        "Think of pH as the \"scoreboard\" and Total Alkalinity as the \"shock absorber\" that keeps the score from changing too quickly."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
            }

            HelpEducationalDisclaimer()
        }
    }
}
