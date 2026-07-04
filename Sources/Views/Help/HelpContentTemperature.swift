//
//  HelpContentTemperature.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/TemperatureContent.jsx`.
//

import SwiftUI

struct HelpTemperatureContent: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Water Temperature Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.color(.textPrimary))

            HelpCollapsibleSection(title: "Ideal Temperature Range", defaultExpanded: true) {
                HelpIdealRange(label: "Recommended range", value: "37–40°C (98–104°F)")
                HelpParagraph(
                    text: "Most people find 38–39°C (100–102°F) most comfortable for extended soaking.",
                    topPadding: 8
                )
            }

            HelpCollapsibleSection(title: "Energy Efficiency Tips") {
                HelpBullet(text: "Keep your cover on when not in use")
                HelpBullet(text: "Lower temperature by 2°C when away for extended periods")
                HelpBullet(text: "Maintain consistent temperature rather than large swings")
                HelpBullet(text: "Check cover condition regularly for heat loss")
            }

            HelpCollapsibleSection(title: "Temperature & Chemistry") {
                HelpInfoBox {
                    Text(
                        "Higher temperatures increase chemical consumption. You may need to test and adjust more frequently in warmer weather or if you prefer hotter water."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.textSecondary))
                }
                HelpBullet(text: "Chlorine/Bromine evaporates faster in hot water")
                HelpBullet(text: "pH can drift more quickly at higher temperatures")
            }

            HelpCollapsibleSection(title: "Safety Considerations") {
                HelpWarningBox {
                    Text(
                        "Temperatures above 40°C (104°F) can be dangerous, especially for pregnant women, young children, and those with heart conditions."
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.color(.statusWarningText))
                }
                HelpBullet(text: "Limit soaking time to 15-20 minutes at maximum temperature")
                HelpBullet(text: "Stay hydrated")
                HelpBullet(text: "Exit immediately if feeling dizzy or uncomfortable")
            }

            HelpEducationalDisclaimerShort(
                text: "This information is for educational purposes only. Always follow your hot tub manufacturer's specific instructions. When in doubt about safe temperature ranges, consult your manufacturer or a qualified pool/spa professional."
            )
        }
    }
}
