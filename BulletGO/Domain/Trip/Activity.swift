import Foundation

nonisolated enum ActivityType: String, Hashable, Codable, Sendable {
    case sightseeing
    case themePark
    case other
}

nonisolated struct Activity: Hashable, Codable, Sendable {
    let id: ActivityID
    var title: Slot<String>
    var type: Slot<ActivityType>
    var scheduledAt: Slot<ScheduledMoment>
    var place: Slot<String>
    var reservation: Reservation
}
