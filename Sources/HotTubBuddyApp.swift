//
//  HotTubBuddyApp.swift
//  HotTub Buddy
//

import SwiftData
import SwiftUI

@main
struct HotTubBuddyApp: App {
    init() {
        _ = ReminderNotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(HotTubModelContainer.shared)
        }
    }
}
