//
//  HotTubModelContainer.swift
//  HotTub Buddy
//

import Foundation
import OSLog
import SwiftData

enum HotTubModelContainer {
    private static let logger = Logger(subsystem: "com.curleybracketsengineering.hottub", category: "SwiftData")

    private static let schema = Schema([
        AppSettings.self,
        HotTubDailyLog.self,
        WeeklyCheckLog.self,
        MaintenanceLogEntry.self,
        UsageLogEntry.self,
    ])

    static let shared: ModelContainer = {
        do {
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.error("SwiftData CloudKit container failed: \(error.localizedDescription, privacy: .public)")
            fatalError("SwiftData container failed: \(error.localizedDescription)")
        }
    }()

    /// Removes duplicate `AppSettings` rows after multi-device sync.
    @MainActor
    static func consolidateSettings(in context: ModelContext) {
        let rows = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard rows.count > 1 else {
            if let only = rows.first, only.settingsKey != "default" {
                only.settingsKey = "default"
                try? context.save()
            }
            return
        }

        let keeper = rows.max(by: { $0.updatedAt < $1.updatedAt }) ?? rows[0]
        keeper.settingsKey = "default"
        for row in rows where row !== keeper {
            context.delete(row)
        }
        try? context.save()
    }

    /// Ensures a single default `AppSettings` row exists.
    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        consolidateSettings(in: context)

        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            context.insert(AppSettings(settingsKey: "default"))
            try? context.save()
        }
    }
}
