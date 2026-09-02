import Foundation

nonisolated enum ReadinessStatus: String, Hashable, Codable, Sendable {
    case ready
    case actionRequired
    case needsMoreInfo
    case unverified
    case notApplicable
}

nonisolated enum DocumentSignal: String, Hashable, Codable, Sendable {
    case found
    case notFound
    case unverified
}

nonisolated enum ReadinessCheckType: String, Hashable, Codable, Sendable {
    case baggageReservation
    case ticketIssuance
    case appInstalled
    case entryTicket
    case other
}

nonisolated struct ReadinessCheck: Hashable, Codable, Sendable {
    let id: ReadinessCheckID
    var checkType: ReadinessCheckType
    var scope: DomainScope
    var relatedPolicyID: PolicyID?
    var status: ReadinessStatus
    var documentSignal: DocumentSignal?
    var detailKey: String?
    var evidenceSources: [String]
    var evaluatedAt: Date?
    var stale: Bool
}
