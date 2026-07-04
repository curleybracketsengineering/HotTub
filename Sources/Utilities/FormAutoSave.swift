//
//  FormAutoSave.swift
//  HotTub
//

import Foundation

@MainActor
final class FormAutoSaveScheduler {
    private var task: Task<Void, Never>?

    func schedule(after seconds: TimeInterval = 0.4, _ action: @escaping () -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func flush(_ action: () -> Void) {
        cancel()
        action()
    }
}

enum FormFieldParsing {
    static func optionalDouble(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let value = Double(trimmed), !value.isNaN else { return nil }
        return value
    }

    static func nonNegativeDouble(from text: String, default defaultValue: Double = 0) -> Double {
        optionalDouble(from: text).map { max(0, $0) } ?? defaultValue
    }
}
