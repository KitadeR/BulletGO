import Foundation

nonisolated enum TransportMode: String, Hashable, Codable, Sendable {
    case shinkansen
    case airplane
    case localTrain
    case bus
    case taxi
    case walking
    case car
    case ferry
    case other
}

nonisolated enum BaggagePresence: String, Hashable, Codable, Sendable {
    case yes
    case no
    case unknown
}

nonisolated struct Leg: Hashable, Codable, Sendable {
    let id: LegID
    var origin: Slot<String>
    var destination: Slot<String>
    var scheduledAt: Slot<ScheduledMoment>
    var arrivesAt: Slot<ScheduledMoment>
    var transportMode: Slot<TransportMode>
    var partyCount: Slot<Int>
    var baggagePresence: Slot<BaggagePresence>
    var seatPreference: Slot<SeatPreference>
    var bagIDs: [BagID]
    var reservation: Reservation
    var phase: LegPhase
    var policyEvaluations: [PolicyEvaluation]
    var activeProcedureIDs: [ProcedureID]
    var originPlace: PlaceReference?
    var destinationPlace: PlaceReference?

    enum CodingKeys: String, CodingKey {
        case id, origin, destination, scheduledAt, arrivesAt, transportMode
        case partyCount, baggagePresence, seatPreference, bagIDs, reservation
        case phase, policyEvaluations, activeProcedureIDs, originPlace, destinationPlace
    }

    init(
        id: LegID,
        origin: Slot<String>,
        destination: Slot<String>,
        scheduledAt: Slot<ScheduledMoment>,
        arrivesAt: Slot<ScheduledMoment>,
        transportMode: Slot<TransportMode>,
        partyCount: Slot<Int>,
        baggagePresence: Slot<BaggagePresence>,
        seatPreference: Slot<SeatPreference>,
        bagIDs: [BagID],
        reservation: Reservation,
        phase: LegPhase,
        policyEvaluations: [PolicyEvaluation],
        activeProcedureIDs: [ProcedureID],
        originPlace: PlaceReference? = nil,
        destinationPlace: PlaceReference? = nil
    ) {
        self.id = id
        self.origin = origin
        self.destination = destination
        self.scheduledAt = scheduledAt
        self.arrivesAt = arrivesAt
        self.transportMode = transportMode
        self.partyCount = partyCount
        self.baggagePresence = baggagePresence
        self.seatPreference = seatPreference
        self.bagIDs = bagIDs
        self.reservation = reservation
        self.phase = phase
        self.policyEvaluations = policyEvaluations
        self.activeProcedureIDs = activeProcedureIDs
        self.originPlace = originPlace
        self.destinationPlace = destinationPlace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(LegID.self, forKey: .id)
        origin = try container.decode(Slot<String>.self, forKey: .origin)
        destination = try container.decode(Slot<String>.self, forKey: .destination)
        scheduledAt = try container.decode(Slot<ScheduledMoment>.self, forKey: .scheduledAt)
        arrivesAt = try container.decodeIfPresent(Slot<ScheduledMoment>.self, forKey: .arrivesAt)
            ?? (try Slot.unknown(updatedAt: scheduledAt.updatedAt))
        transportMode = try container.decode(Slot<TransportMode>.self, forKey: .transportMode)
        partyCount = try container.decode(Slot<Int>.self, forKey: .partyCount)
        baggagePresence = try container.decode(Slot<BaggagePresence>.self, forKey: .baggagePresence)
        seatPreference = try container.decode(Slot<SeatPreference>.self, forKey: .seatPreference)
        bagIDs = try container.decode([BagID].self, forKey: .bagIDs)
        reservation = try container.decode(Reservation.self, forKey: .reservation)
        phase = try container.decode(LegPhase.self, forKey: .phase)
        policyEvaluations = try container.decode([PolicyEvaluation].self, forKey: .policyEvaluations)
        activeProcedureIDs = try container.decode([ProcedureID].self, forKey: .activeProcedureIDs)
        originPlace = try container.decodeIfPresent(PlaceReference.self, forKey: .originPlace)
        destinationPlace = try container.decodeIfPresent(PlaceReference.self, forKey: .destinationPlace)
    }
}
