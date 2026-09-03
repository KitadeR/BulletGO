import Foundation

nonisolated enum TripMutation: Hashable, Sendable {
    case setLegScheduledAt(LegID, ScheduledMoment)
    case setTransportMode(LegID, TransportMode)
    case setReservationStatus(LegID, ReservationStatus?, SlotStatus)
    case setBookingService(LegID, BookingService)
    case setBaggagePresence(LegID, BaggagePresence?, SlotStatus)
    case addBag(LegID, BagID)
    case setBagDimensions(BagID, BaggageDimensions)
}

nonisolated enum QuestionAnswer: Hashable, Sendable {
    case scheduledMoment(ScheduledMoment)
    case choice(String)
    case skip
    case dimensions(BaggageDimensions)
}

nonisolated enum PhaseManualEvent: Hashable, Sendable {
    case startPreparing
    case startGoingToDeparture
    case arriveAtDeparture
    case startBoarding
    case startTransit
    case arrive
    case complete
}

nonisolated enum TypedCommand: Hashable, Sendable {
    case answerQuestion(QuestionID, QuestionAnswer)
    case applyMutation(TripMutation)
    case applyPhaseEvent(PhaseManualEvent)
    case reevaluate
}
