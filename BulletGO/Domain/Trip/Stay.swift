import Foundation

nonisolated struct Stay: Hashable, Codable, Sendable {
    let id: StayID
    var place: Slot<String>
    var checkIn: Slot<ScheduledMoment>
    var checkOut: Slot<ScheduledMoment>
    var reservation: Reservation
    var placeReference: PlaceReference?

    enum CodingKeys: String, CodingKey {
        case id, place, checkIn, checkOut, reservation, placeReference
    }

    init(
        id: StayID,
        place: Slot<String>,
        checkIn: Slot<ScheduledMoment>,
        checkOut: Slot<ScheduledMoment>,
        reservation: Reservation,
        placeReference: PlaceReference? = nil
    ) {
        self.id = id
        self.place = place
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.reservation = reservation
        self.placeReference = placeReference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(StayID.self, forKey: .id)
        place = try container.decode(Slot<String>.self, forKey: .place)
        checkIn = try container.decode(Slot<ScheduledMoment>.self, forKey: .checkIn)
        checkOut = try container.decode(Slot<ScheduledMoment>.self, forKey: .checkOut)
        reservation = try container.decode(Reservation.self, forKey: .reservation)
        placeReference = try container.decodeIfPresent(PlaceReference.self, forKey: .placeReference)
    }
}
