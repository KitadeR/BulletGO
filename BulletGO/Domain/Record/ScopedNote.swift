import Foundation

nonisolated struct ScopedNote: Hashable, Codable, Sendable, Identifiable {
    let id: NoteID
    var scope: DomainScope
    var body: String
    var updatedAt: Date
}

nonisolated struct AttachmentRecord: Hashable, Codable, Sendable, Identifiable {
    let id: AttachmentID
    var scope: DomainScope
    var fileName: String
    var utType: String
    var relativePath: String
    var createdAt: Date
}
