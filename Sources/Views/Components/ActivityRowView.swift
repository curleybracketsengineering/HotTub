//
//  ActivityRowView.swift
//  HotTub Buddy
//

import SwiftUI

struct ActivityRowView: View {
    let row: HistoryRow
    let isBromine: Bool
    let palette: AppPalette

    var body: some View {
        HStack(spacing: AppSpacing.control) {
            Image(systemName: rowIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.color(.textPrimary))
                Text(RelativeDateFormatter.relativeDayAndTime(for: row.sortMoment))
                    .font(.caption)
                    .foregroundStyle(palette.color(.textSecondary))
            }

            Spacer(minLength: 8)

            if case .daily(let log) = row {
                HStack(spacing: 8) {
                    if let ph = log.ph {
                        Text("pH \(String(format: "%.1f", ph))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(phWarning(log) ? palette.color(.accentOrange) : palette.color(.textSecondary))
                    }
                    if let ppm = log.primarySanitizerPpm {
                        Text("\(isBromine ? "BR" : "CL") \(String(format: "%.1f", ppm))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(sanitizerWarning(log) ? palette.color(.accentOrange) : palette.color(.textSecondary))
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.color(.textTertiary))
        }
    }

    private var rowIcon: String {
        switch row {
        case .weekly:
            "checkmark.circle.fill"
        default:
            row.kind.systemImage
        }
    }

    private var accent: Color {
        switch row {
        case .weekly:
            palette.color(.accentGreen)
        default:
            palette.color(row.kind.iconToken)
        }
    }

    private func phWarning(_ log: HotTubDailyLog) -> Bool {
        guard let ph = log.ph else { return false }
        return ph < 7.2 || ph > 7.8
    }

    private func sanitizerWarning(_ log: HotTubDailyLog) -> Bool {
        guard let ppm = log.primarySanitizerPpm else { return false }
        if isBromine { return ppm < 3.0 || ppm > 5.0 }
        return ppm < 1.0 || ppm > 3.0
    }
}
