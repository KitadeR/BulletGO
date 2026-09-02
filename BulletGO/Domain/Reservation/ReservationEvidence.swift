import Foundation

nonisolated enum ReservationEvidenceLevel: String, Hashable, Codable, Sendable {
    case userStated
    case documentParsed
    case officiallyVerified
}

nonisolated enum ReservationDocumentType: String, Hashable, Codable, Sendable {
    case screenshot
    case pdf
}

nonisolated struct ReservationEvidenceRecord: Hashable, Codable, Sendable {
    var level: ReservationEvidenceLevel
    var capturedAt: Date
    var sourceTaskID: TaskID?
    var documentType: ReservationDocumentType?
}
