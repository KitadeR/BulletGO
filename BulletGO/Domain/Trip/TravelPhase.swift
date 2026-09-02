import Foundation

nonisolated enum TripPhase: String, Hashable, Codable, Sendable {
    case planning
    case beforeTrip
    case inTrip
    case finished
}

nonisolated enum LegPhase: String, Hashable, Codable, Sendable {
    case planning
    case booking
    case preparing
    case goingToDeparture
    case atDeparture
    case boarding
    case inTransit
    case arriving
    case completed
}
