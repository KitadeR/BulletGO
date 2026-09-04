import Foundation

nonisolated enum TripMutation: Hashable, Sendable {
    case setTripName(String)
    case setTripStartDate(LocalDate)
    case setTripEndDate(LocalDate)
    case addLeg(Leg, atTimelineIndex: Int?)
    case updateLegOrigin(LegID, String)
    case updateLegDestination(LegID, String)
    case unscheduleLeg(LegID)
    case removeLeg(LegID)
    case addStay(Stay, atTimelineIndex: Int?)
    case updateStayPlace(StayID, String)
    case updateStayCheckIn(StayID, ScheduledMoment)
    case updateStayCheckOut(StayID, ScheduledMoment)
    case unscheduleStay(StayID)
    case removeStay(StayID)
    case addActivity(Activity, atTimelineIndex: Int?)
    case updateActivityTitle(ActivityID, String)
    case updateActivityPlace(ActivityID, String)
    case updateActivityScheduledAt(ActivityID, ScheduledMoment)
    case unscheduleActivity(ActivityID)
    case removeActivity(ActivityID)
    case moveTimelineItem(from: Int, to: Int)
    case setLegScheduledAt(LegID, ScheduledMoment)
    case setTransportMode(LegID, TransportMode)
    case setReservationStatus(LegID, ReservationStatus?, SlotStatus)
    case setBookingService(LegID, BookingService)
    case setBaggagePresence(LegID, BaggagePresence?, SlotStatus)
    case addBag(LegID, BagID)
    case setBagDimensions(BagID, BaggageDimensions)
    case setSeatPreference(LegID, SeatPreference)

    var isStructural: Bool {
        switch self {
        case .setTripName, .setTripStartDate, .setTripEndDate,
             .addLeg, .updateLegOrigin, .updateLegDestination, .unscheduleLeg, .removeLeg,
             .addStay, .updateStayPlace, .updateStayCheckIn, .updateStayCheckOut, .unscheduleStay, .removeStay,
             .addActivity, .updateActivityTitle, .updateActivityPlace, .updateActivityScheduledAt, .unscheduleActivity, .removeActivity,
             .moveTimelineItem:
            true
        case .setLegScheduledAt, .setTransportMode, .setReservationStatus, .setBookingService,
             .setBaggagePresence, .addBag, .setBagDimensions, .setSeatPreference:
            false
        }
    }
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
    case applyMutations([TripMutation])
    case applyPhaseEvent(PhaseManualEvent)
    case reachDecisionPoint(DecisionPointID)
    case focusLeg(LegID)
    case reevaluate
}
