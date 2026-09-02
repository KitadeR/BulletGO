import Foundation

nonisolated enum CurrentFocus: Hashable, Codable, Sendable {
    case none
    case leg(LegID)
    case activity(ActivityID)
}

nonisolated struct CurrentContext: Hashable, Codable, Sendable {
    var tripID: TripID
    var focus: CurrentFocus
    var tripPhase: TripPhase
}
