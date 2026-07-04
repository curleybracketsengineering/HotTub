//
//  HelpContentDefault.swift
//  HotTub
//
//  Migrated from React `HelpModal/content/DefaultContent.jsx`.
//

import SwiftUI

struct HelpDefaultContent: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        Text("Help content not available for this topic.")
            .font(.body)
            .foregroundStyle(palette.color(.textSecondary))
    }
}
