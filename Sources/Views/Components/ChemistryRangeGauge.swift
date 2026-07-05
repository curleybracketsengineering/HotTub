//
//  ChemistryRangeGauge.swift
//  HotTub
//

import SwiftUI

/// Horizontal gauge showing a reading against an ideal band on a coloured hero surface.
struct ChemistryRangeGauge: View {
    let value: Double?
    let idealRange: ClosedRange<Double>
    let displayRange: ClosedRange<Double>
    let status: WaterChemistryReadingStatus?
    var trackOpacity: Double = 0.22
    var idealOpacity: Double = 0.55

    @Environment(\.appPalette) private var palette

    private let trackHeight: CGFloat = 8
    private let indicatorSize: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let idealStart = position(for: idealRange.lowerBound, width: width)
            let idealEnd = position(for: idealRange.upperBound, width: width)
            let idealWidth = max(idealEnd - idealStart, 4)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(trackOpacity))
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(palette.color(.accentGreen).opacity(idealOpacity))
                    .frame(width: idealWidth, height: trackHeight)
                    .offset(x: idealStart)

                if let value {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .offset(x: position(for: value, width: width) - indicatorSize / 2)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: indicatorSize)
    }

    private var indicatorColor: Color {
        guard let status else { return palette.color(.onAccent) }
        switch status {
        case .inRange:
            return palette.color(.onAccent)
        case .caution:
            return palette.color(.accentYellow)
        case .attention:
            return palette.color(.accentOrange)
        }
    }

    private func position(for value: Double, width: CGFloat) -> CGFloat {
        let span = displayRange.upperBound - displayRange.lowerBound
        guard span > 0 else { return width / 2 }
        let clamped = min(max(value, displayRange.lowerBound), displayRange.upperBound)
        let fraction = (clamped - displayRange.lowerBound) / span
        return CGFloat(fraction) * width
    }
}

extension WaterChemistryRanges {
    static let phDisplay: ClosedRange<Double> = 6.8 ... 8.2
    static let chlorineDisplay: ClosedRange<Double> = 0 ... 5
    static let bromineDisplay: ClosedRange<Double> = 0 ... 6
}
