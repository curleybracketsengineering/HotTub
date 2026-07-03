//
//  CSVBackupFileWriter.swift
//  HotTub Buddy
//

import Foundation

enum CSVBackupFileWriter {
    private static let backupsFolderName = "Backups"

    /// App Documents subdirectory where CSV backups are stored (visible in Files when UIFileSharingEnabled is on).
    static func backupsDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = documents.appendingPathComponent(backupsFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    static func writeBackupCSV(text: String, filename: String) throws -> URL {
        let directory = try backupsDirectory()
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        guard let data = text.data(using: .utf8), !data.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
