import Foundation
import UniformTypeIdentifiers

protocol AttachmentStoring: Sendable {
    func importFile(
        from source: URL,
        tripID: TripID,
        fileName: String,
        utType: UTType
    ) throws -> AttachmentRecord

    func importData(
        _ data: Data,
        tripID: TripID,
        fileName: String,
        utType: UTType,
        scope: DomainScope
    ) throws -> AttachmentRecord

    func url(for record: AttachmentRecord) -> URL
    func delete(_ record: AttachmentRecord) throws
    func trash(_ record: AttachmentRecord) throws
    func restore(_ record: AttachmentRecord) throws
    func deleteTripDirectory(tripID: TripID) throws
    func cleanupExpiredTrash(olderThan: TimeInterval) throws
}

struct AttachmentStore: AttachmentStoring, Sendable {
    var root: URL

    static func applicationSupport() throws -> AttachmentStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appending(path: "BulletGO/Attachments", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return AttachmentStore(root: root)
    }

    func importFile(
        from source: URL,
        tripID: TripID,
        fileName: String,
        utType: UTType
    ) throws -> AttachmentRecord {
        let accessed = source.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                source.stopAccessingSecurityScopedResource()
            }
        }
        let id = AttachmentID()
        let safeName = sanitized(fileName)
        try stage(tripID: tripID, id: id, fileName: safeName) { destination in
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return AttachmentRecord(
            id: id,
            scope: .trip,
            fileName: safeName,
            utType: utType.identifier,
            relativePath: "\(tripID.rawValue.uuidString)/\(id.rawValue.uuidString)/\(safeName)",
            createdAt: Date()
        )
    }

    func importData(
        _ data: Data,
        tripID: TripID,
        fileName: String,
        utType: UTType,
        scope: DomainScope
    ) throws -> AttachmentRecord {
        let id = AttachmentID()
        let safeName = sanitized(fileName)
        try stage(tripID: tripID, id: id, fileName: safeName) { destination in
            try data.write(to: destination, options: .atomic)
        }
        return AttachmentRecord(
            id: id,
            scope: scope,
            fileName: safeName,
            utType: utType.identifier,
            relativePath: "\(tripID.rawValue.uuidString)/\(id.rawValue.uuidString)/\(safeName)",
            createdAt: Date()
        )
    }

    func url(for record: AttachmentRecord) -> URL {
        root.appending(path: record.relativePath, directoryHint: .notDirectory)
    }

    func delete(_ record: AttachmentRecord) throws {
        let url = url(for: record)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        try? FileManager.default.removeItem(at: trashURL(for: record).deletingLastPathComponent())
    }

    func trash(_ record: AttachmentRecord) throws {
        let source = url(for: record).deletingLastPathComponent()
        let destination = trashURL(for: record).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: source.path) else {
            return
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func restore(_ record: AttachmentRecord) throws {
        let source = trashURL(for: record).deletingLastPathComponent()
        let destination = url(for: record).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: source.path) else {
            return
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func deleteTripDirectory(tripID: TripID) throws {
        let folder = root.appending(path: tripID.rawValue.uuidString, directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
        let trash = trashRoot.appending(path: tripID.rawValue.uuidString, directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: trash.path) {
            try FileManager.default.removeItem(at: trash)
        }
    }

    func cleanupExpiredTrash(olderThan: TimeInterval) throws {
        try removeExpiredLeaves(in: trashRoot, olderThan: olderThan)
        try removeExpiredLeaves(in: stagingRoot, olderThan: olderThan)
    }

    private var trashRoot: URL {
        root.appending(path: ".trash", directoryHint: .isDirectory)
    }

    private func trashURL(for record: AttachmentRecord) -> URL {
        trashRoot.appending(path: record.relativePath, directoryHint: .notDirectory)
    }

    private var stagingRoot: URL {
        root.appending(path: ".staging", directoryHint: .isDirectory)
    }

    private func directory(tripID: TripID, id: AttachmentID) -> URL {
        root
            .appending(path: tripID.rawValue.uuidString, directoryHint: .isDirectory)
            .appending(path: id.rawValue.uuidString, directoryHint: .isDirectory)
    }

    private func stage(
        tripID: TripID,
        id: AttachmentID,
        fileName: String,
        write: (URL) throws -> Void
    ) throws {
        let stagingFolder = stagingRoot
            .appending(path: tripID.rawValue.uuidString, directoryHint: .isDirectory)
            .appending(path: id.rawValue.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        let stagingFile = stagingFolder.appending(path: fileName, directoryHint: .notDirectory)
        do {
            try write(stagingFile)
            let finalFolder = directory(tripID: tripID, id: id)
            try FileManager.default.createDirectory(
                at: finalFolder.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: finalFolder.path) {
                try FileManager.default.removeItem(at: finalFolder)
            }
            try FileManager.default.moveItem(at: stagingFolder, to: finalFolder)
            let stagingTrip = stagingFolder.deletingLastPathComponent()
            let leftover = try FileManager.default.contentsOfDirectory(
                at: stagingTrip,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            if leftover.isEmpty {
                try FileManager.default.removeItem(at: stagingTrip)
            }
        } catch {
            try? FileManager.default.removeItem(at: stagingFolder)
            throw error
        }
    }

    private func removeExpiredLeaves(in directory: URL, olderThan: TimeInterval, now: Date = Date()) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        let cutoff = now.addingTimeInterval(-olderThan)
        let tripFolders = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for tripFolder in tripFolders {
            let attachmentFolders = try FileManager.default.contentsOfDirectory(
                at: tripFolder,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for folder in attachmentFolders {
                let values = try folder.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
                guard values.isDirectory == true else {
                    continue
                }
                if (values.contentModificationDate ?? now) < cutoff {
                    try FileManager.default.removeItem(at: folder)
                }
            }
            let remaining = try FileManager.default.contentsOfDirectory(
                at: tripFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            if remaining.isEmpty {
                try FileManager.default.removeItem(at: tripFolder)
            }
        }
    }

    private func sanitized(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-")
        return cleaned.isEmpty ? "attachment" : cleaned
    }
}
