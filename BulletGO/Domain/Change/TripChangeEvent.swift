import Foundation

nonisolated enum ChangeEventKind: String, Hashable, Codable, Sendable {
    case luggageAdded
    case transportChanged
    case dateChanged
    case reservationUpdated
    case other
}

nonisolated enum ChangeImpactLevel: String, Hashable, Codable, Sendable {
    case low
    case medium
    case high
}

nonisolated enum ChangeScope: Hashable, Codable, Sendable {
    case none
    case futureLegs
    case specificLegs([LegID])
    case entireTrip
}

nonisolated struct TripChangeEvent: Hashable, Codable, Sendable {
    let id: ChangeEventID
    var kind: ChangeEventKind
    var target: DomainScope
    var changedPaths: [DomainPath]
    var affectedFrom: LocalDate?
    var potentialScope: ChangeScope
    var impactLevel: ChangeImpactLevel
    let createdAt: Date
}
