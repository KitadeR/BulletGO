import Foundation
import UniformTypeIdentifiers

struct AttachmentStore: Sendable {
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
        let folder = directory(tripID: tripID, id: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = sanitized(fileName)
        let destination = folder.appending(path: safeName, directoryHint: .notDirectory)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
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
        let folder = directory(tripID: tripID, id: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = sanitized(fileName)
        let destination = folder.appending(path: safeName, directoryHint: .notDirectory)
        try data.write(to: destination, options: .atomic)
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
    }

    private func directory(tripID: TripID, id: AttachmentID) -> URL {
        root
            .appending(path: tripID.rawValue.uuidString, directoryHint: .isDirectory)
            .appending(path: id.rawValue.uuidString, directoryHint: .isDirectory)
    }

    private func sanitized(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-")
        return cleaned.isEmpty ? "attachment" : cleaned
    }
}
