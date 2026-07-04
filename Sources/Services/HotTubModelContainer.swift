//
//  HotTubModelContainer.swift
//  HotTub
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
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return preview
        }
        #endif

        do {
            return try makeContainer()
        } catch {
            logger.error("SwiftData CloudKit container failed: \(error.localizedDescription, privacy: .public)")
            fatalError("SwiftData container failed: \(error.localizedDescription)")
        }
    }()

    /// In-memory store for Canvas previews — never uses CloudKit.
    static let preview: ModelContainer = {
        do {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Preview ModelContainer failed: \(error.localizedDescription)")
        }
    }()

    private static func makeContainer() throws -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: cloudConfig)
        } catch {
            // Allow schema migration from a prior local-only store, then retry CloudKit.
            logger.warning("CloudKit store open failed, running local migration pass: \(error.localizedDescription, privacy: .public)")
            let localConfig = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
            _ = try ModelContainer(for: schema, configurations: localConfig)
            return try ModelContainer(for: schema, configurations: cloudConfig)
        }
    }

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
