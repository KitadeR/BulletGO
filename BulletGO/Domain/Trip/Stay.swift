import Foundation

nonisolated struct Stay: Hashable, Codable, Sendable {
    let id: StayID
    var place: Slot<String>
    var checkIn: Slot<ScheduledMoment>
    var checkOut: Slot<ScheduledMoment>
    var reservation: Reservation
}
