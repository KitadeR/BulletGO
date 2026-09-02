import Foundation

nonisolated enum TransportMode: String, Hashable, Codable, Sendable {
    case shinkansen
    case airplane
    case localTrain
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
    var transportMode: Slot<TransportMode>
    var partyCount: Slot<Int>
    var baggagePresence: Slot<BaggagePresence>
    var bagIDs: [BagID]
    var reservation: Reservation
    var phase: LegPhase
    var policyEvaluations: [PolicyEvaluation]
    var activeProcedureIDs: [ProcedureID]
}
