import Foundation

nonisolated enum TripTimelineItem: Hashable, Codable, Sendable {
    case leg(LegID)
    case activity(ActivityID)
}
