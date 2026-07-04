//
//  PreviewEnvironment.swift
//  HotTub
//

import Foundation

enum PreviewEnvironment {
    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        false
        #endif
    }
}
