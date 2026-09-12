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
    var endsAt: Slot<ScheduledMoment>
    var place: Slot<String>
    var reservation: Reservation
    var placeReference: PlaceReference?

    enum CodingKeys: String, CodingKey {
        case id, title, type, scheduledAt, endsAt, place, reservation, placeReference
    }

    init(
        id: ActivityID,
        title: Slot<String>,
        type: Slot<ActivityType>,
        scheduledAt: Slot<ScheduledMoment>,
        endsAt: Slot<ScheduledMoment>,
        place: Slot<String>,
        reservation: Reservation,
        placeReference: PlaceReference? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.scheduledAt = scheduledAt
        self.endsAt = endsAt
        self.place = place
        self.reservation = reservation
        self.placeReference = placeReference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ActivityID.self, forKey: .id)
        title = try container.decode(Slot<String>.self, forKey: .title)
        type = try container.decode(Slot<ActivityType>.self, forKey: .type)
        scheduledAt = try container.decode(Slot<ScheduledMoment>.self, forKey: .scheduledAt)
        endsAt = try container.decodeIfPresent(Slot<ScheduledMoment>.self, forKey: .endsAt)
            ?? (try Slot.unknown(updatedAt: scheduledAt.updatedAt))
        place = try container.decode(Slot<String>.self, forKey: .place)
        reservation = try container.decode(Reservation.self, forKey: .reservation)
        placeReference = try container.decodeIfPresent(PlaceReference.self, forKey: .placeReference)
    }
}
