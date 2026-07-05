//
//  HotTubDataRefresh.swift
//  HotTub
//

import Foundation

extension Notification.Name {
    /// Posted after SwiftData log entries are saved or deleted so live views can reload.
    static let hotTubLocalStoreDidChange = Notification.Name("HotTubLocalStoreDidChange")
}

enum HotTubDataRefresh {
    static func notifyLocalStoreChanged() {
        NotificationCenter.default.post(name: .hotTubLocalStoreDidChange, object: nil)
    }
}
