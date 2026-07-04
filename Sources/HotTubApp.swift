//
//  HotTubApp.swift
//  HotTub
//

import SwiftData
import SwiftUI

@main
struct HotTubApp: App {
    init() {
        guard !PreviewEnvironment.isActive else { return }
        _ = ReminderNotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(HotTubModelContainer.shared)
        }
    }
}
