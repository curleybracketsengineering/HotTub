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
            Image(systemName: row.kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.color(.textPrimary))
                HStack(spacing: 8) {
                    Text(formatShortDate(row.sortMoment))
                    Text(timeString(row.sortMoment))
                }
                .font(.caption)
                .foregroundStyle(palette.color(.textPrimary).opacity(0.75))

                if case .daily(let log) = row {
                    HStack(spacing: 10) {
                        if let ph = log.ph {
                            Text("pH \(String(format: "%.1f", ph))")
                                .font(.caption)
                                .foregroundStyle(phWarning(log) ? palette.color(.accentOrange) : palette.color(.textSecondary))
                        }
                        if let ppm = log.primarySanitizerPpm {
                            Text("\(isBromine ? "BR" : "FC") \(String(format: "%.1f", ppm))")
                                .font(.caption)
                                .foregroundStyle(sanitizerWarning(log) ? palette.color(.accentOrange) : palette.color(.textSecondary))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.color(.textTertiary))
        }
    }

    private var accent: Color {
        palette.color(row.kind.iconToken)
    }

    private func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yy"
        return f.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
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
