//
//  ReminderNotificationService.swift
//  HotTub
//

import Combine
import Foundation
import SwiftData
import UserNotifications

enum ReminderNotificationDestination: String, Equatable {
    case dailyLog
    case weeklyCheck
    case maintenanceFilterRinse
    case maintenanceFilterChange
    case maintenanceWaterChange
}

@MainActor
final class ReminderNotificationService: NSObject, ObservableObject {
    static let shared = ReminderNotificationService()

    private enum Identifier {
        static let daily = "hot-tub.daily"
        static let weekly = "hot-tub.weekly"
        static let filterRinse = "hot-tub.filter-rinse"
        static let filterChange = "hot-tub.filter-change"
        static let waterChange = "hot-tub.water-change"

        static var all: [String] {
            [daily, weekly, filterRinse, filterChange, waterChange]
        }
    }

    private enum StorageKey {
        static let remindersEnabled = "reminderNotificationsEnabled"
        static let reminderHour = "reminderNotificationHour"
        static let reminderMinute = "reminderNotificationMinute"
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingDestination: ReminderNotificationDestination?

    var remindersEnabled: Bool {
        get { UserDefaults.standard.object(forKey: StorageKey.remindersEnabled) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.remindersEnabled)
            guard !PreviewEnvironment.isActive else { return }
            if newValue {
                Task { await rescheduleFromSharedContainer() }
            } else {
                cancelAll()
            }
        }
    }

    var preferredReminderTime: Date {
        get {
            let hour = UserDefaults.standard.object(forKey: StorageKey.reminderHour) as? Int ?? 9
            let minute = UserDefaults.standard.object(forKey: StorageKey.reminderMinute) as? Int ?? 0
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return Calendar.current.date(from: components) ?? defaultReminderTime
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            UserDefaults.standard.set(parts.hour ?? 9, forKey: StorageKey.reminderHour)
            UserDefaults.standard.set(parts.minute ?? 0, forKey: StorageKey.reminderMinute)
            guard !PreviewEnvironment.isActive else { return }
            Task { await rescheduleFromSharedContainer() }
        }
    }

    private var defaultReminderTime: Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? .now
    }

    private override init() {
        super.init()
        guard !PreviewEnvironment.isActive else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func refreshAuthorizationStatus() async {
        guard !PreviewEnvironment.isActive else {
            authorizationStatus = .notDetermined
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard !PreviewEnvironment.isActive else { return false }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await refreshAuthorizationStatus()
            if granted {
                await rescheduleFromSharedContainer()
            }
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func reschedule(context: ModelContext) async {
        guard !PreviewEnvironment.isActive else { return }
        guard remindersEnabled else {
            cancelAll()
            return
        }

        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            cancelAll()
            return
        }

        let daily = (try? context.fetch(FetchDescriptor<HotTubDailyLog>())) ?? []
        let weekly = (try? context.fetch(FetchDescriptor<WeeklyCheckLog>())) ?? []
        let maintenance = (try? context.fetch(FetchDescriptor<MaintenanceLogEntry>())) ?? []
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        let settings = settingsList.first

        let lastDaily = daily.sorted { $0.loggedAt > $1.loggedAt }.first?.loggedAt
        let lastWeekly = weekly.sorted { $0.loggedAt > $1.loggedAt }.first?.loggedAt
        let maintenanceDates = ReminderSchedule.lastMaintenanceDates(from: maintenance)
        let lastFilterRinse = maintenanceDates.filterRinse
        let lastFilterChange = maintenanceDates.filterChange
        let lastWaterChange = maintenanceDates.waterChange

        await scheduleNotifications(
            settings: settings,
            lastDaily: lastDaily,
            lastWeekly: lastWeekly,
            lastFilterRinse: lastFilterRinse,
            lastFilterChange: lastFilterChange,
            lastWaterChange: lastWaterChange
        )
    }

    func rescheduleFromSharedContainer() async {
        guard !PreviewEnvironment.isActive else { return }
        let context = ModelContext(HotTubModelContainer.shared)
        await reschedule(context: context)
    }

    private func scheduleNotifications(
        settings: AppSettings?,
        lastDaily: Date?,
        lastWeekly: Date?,
        lastFilterRinse: Date?,
        lastFilterChange: Date?,
        lastWaterChange: Date?
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Identifier.all)

        guard let settings else { return }

        if settings.reminderWaterTestEnabled,
           ReminderSchedule.isPastDue(last: lastDaily, intervalDays: settings.reminderWaterTestDays) {
            let dueDate = ReminderSchedule.dueDate(after: lastDaily, intervalDays: settings.reminderWaterTestDays)
            if let triggerDate = nextFireDate(onOrAfter: dueDate) {
                await addRequest(
                    identifier: Identifier.daily,
                    title: "Water test",
                    body: "Record today's water readings to keep your hot tub on track.",
                    destination: .dailyLog,
                    fireDate: triggerDate
                )
            }
        }

        if settings.reminderWeeklyCheckEnabled,
           ReminderSchedule.isPastDue(last: lastWeekly, intervalDays: settings.reminderWeeklyCheckDays) {
            let dueDate = ReminderSchedule.dueDate(after: lastWeekly, intervalDays: settings.reminderWeeklyCheckDays)
            if let triggerDate = nextFireDate(onOrAfter: dueDate) {
                await addRequest(
                    identifier: Identifier.weekly,
                    title: "Full water check",
                    body: "Time for a full weekly check of your hot tub water.",
                    destination: .weeklyCheck,
                    fireDate: triggerDate
                )
            }
        }

        if settings.reminderFilterRinseEnabled,
           ReminderSchedule.isPastDue(last: lastFilterRinse, intervalDays: settings.reminderFilterRinseDays) {
            let dueDate = ReminderSchedule.dueDate(after: lastFilterRinse, intervalDays: settings.reminderFilterRinseDays)
            if let triggerDate = nextFireDate(onOrAfter: dueDate) {
                await addRequest(
                    identifier: Identifier.filterRinse,
                    title: "Rinse filter",
                    body: "Rinse your filter to keep water flowing cleanly.",
                    destination: .maintenanceFilterRinse,
                    fireDate: triggerDate
                )
            }
        }

        if settings.reminderFilterChangeEnabled,
           ReminderSchedule.isPastDue(last: lastFilterChange, intervalMonths: settings.reminderFilterChangeMonths) {
            let dueDate = ReminderSchedule.dueDate(after: lastFilterChange, intervalMonths: settings.reminderFilterChangeMonths)
            if let triggerDate = nextFireDate(onOrAfter: dueDate) {
                await addRequest(
                    identifier: Identifier.filterChange,
                    title: "Change filter",
                    body: "Your filter cartridge may be due for replacement.",
                    destination: .maintenanceFilterChange,
                    fireDate: triggerDate
                )
            }
        }

        if settings.reminderWaterChangeEnabled,
           ReminderSchedule.isPastDue(last: lastWaterChange, intervalDays: settings.reminderWaterChangeDays) {
            let dueDate = ReminderSchedule.dueDate(after: lastWaterChange, intervalDays: settings.reminderWaterChangeDays)
            if let triggerDate = nextFireDate(onOrAfter: dueDate) {
                await addRequest(
                    identifier: Identifier.waterChange,
                    title: "Water change",
                    body: "Consider draining and refilling your hot tub.",
                    destination: .maintenanceWaterChange,
                    fireDate: triggerDate
                )
            }
        }
    }

    private func nextFireDate(onOrAfter dueDate: Date) -> Date? {
        let calendar = Calendar.current
        let timeParts = calendar.dateComponents([.hour, .minute], from: preferredReminderTime)
        var dueComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
        dueComponents.hour = timeParts.hour
        dueComponents.minute = timeParts.minute
        dueComponents.second = 0

        guard var fireDate = calendar.date(from: dueComponents) else { return nil }
        if fireDate < .now {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }
        return fireDate
    }

    private func addRequest(
        identifier: String,
        title: String,
        body: String,
        destination: ReminderNotificationDestination,
        fireDate: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["destination": destination.rawValue]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func cancelAll() {
        guard !PreviewEnvironment.isActive else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Identifier.all
        )
    }
}

extension ReminderNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let raw = userInfo["destination"] as? String,
              let destination = ReminderNotificationDestination(rawValue: raw) else { return }
        await MainActor.run {
            pendingDestination = destination
        }
    }
}
