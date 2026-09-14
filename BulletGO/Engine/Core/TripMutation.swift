import Foundation

nonisolated enum TripDateRangeHandling: Hashable, Sendable {
    case rejectOutOfRange
    case moveOutOfRangeToUnscheduledPreservingTiming
}

nonisolated enum TripMutation: Hashable, Sendable {
    case setTripName(String)
    case setTripStartDate(LocalDate)
    case setTripEndDate(LocalDate)
    case setTripDateRange(start: LocalDate, end: LocalDate, handling: TripDateRangeHandling)
    case addLeg(Leg, atTimelineIndex: Int?)
    case updateLegOrigin(LegID, PlaceReference)
    case updateLegDestination(LegID, PlaceReference)
    case unscheduleLeg(LegID)
    case removeLeg(LegID)
    case addStay(Stay, atTimelineIndex: Int?)
    case updateStayPlace(StayID, PlaceReference)
    case updateStayCheckIn(StayID, ScheduledMoment)
    case updateStayCheckOut(StayID, ScheduledMoment)
    case unscheduleStay(StayID)
    case removeStay(StayID)
    case addActivity(Activity, atTimelineIndex: Int?)
    case updateActivityTitle(ActivityID, String)
    case updateActivityPlace(ActivityID, PlaceReference)
    case updateActivityScheduledAt(ActivityID, ScheduledMoment)
    case unscheduleActivity(ActivityID)
    case removeActivity(ActivityID)
    case moveTimelineItem(from: Int, to: Int)
    case moveTimelineItemID(TripTimelineItem, toIndex: Int)
    case setLegScheduledAt(LegID, ScheduledMoment)
    case setTransportMode(LegID, TransportMode)
    case setReservationStatus(LegID, ReservationStatus?, SlotStatus)
    case setBookingService(LegID, BookingService)
    case setBaggagePresence(LegID, BaggagePresence?, SlotStatus)
    case addBag(LegID, BagID)
    case setBagDimensions(BagID, BaggageDimensions)
    case setSeatPreference(LegID, SeatPreference)
    case updateLegArrivesAt(LegID, ScheduledMoment)
    case updateActivityEndsAt(ActivityID, ScheduledMoment?)
    case replaceLegSchedule(LegID, departure: ScheduledMoment?, arrival: ScheduledMoment?)
    case replaceStaySchedule(StayID, checkIn: ScheduledMoment?, checkOut: ScheduledMoment?)
    case replaceActivitySchedule(ActivityID, start: ScheduledMoment?, end: ScheduledMoment?)
    case moveItemToDate(TripTimelineItem, LocalDate?)
    case updateReservationDetails(DomainScope, ReservationDetails)
    case updateScopedReservationStatus(DomainScope, ReservationStatus, SlotStatus)
    case upsertNote(ScopedNote)
    case removeNote(NoteID)
    case addAttachment(AttachmentRecord)
    case renameAttachment(AttachmentID, String)
    case removeAttachment(AttachmentID)
    case addSavedPlace(SavedPlace)
    case removeSavedPlace(SavedPlaceID)
    case cacheConnectorEstimate(ConnectorEstimate)
    case setDaySubtitle(LocalDate, String?)
    case restoreItineraryItem(DeletedItineraryItemBundle)

    var recordsChangeEvent: Bool {
        switch self {
        case .cacheConnectorEstimate:
            false
        default:
            true
        }
    }

    var isStructural: Bool {
        switch self {
        case .setTripName, .setTripStartDate, .setTripEndDate, .setTripDateRange,
             .addLeg, .updateLegOrigin, .updateLegDestination, .unscheduleLeg, .removeLeg,
             .addStay, .updateStayPlace, .updateStayCheckIn, .updateStayCheckOut, .unscheduleStay, .removeStay,
             .addActivity, .updateActivityTitle, .updateActivityPlace, .updateActivityScheduledAt, .unscheduleActivity, .removeActivity,
             .moveTimelineItem, .moveTimelineItemID, .updateLegArrivesAt, .updateActivityEndsAt, .moveItemToDate,
             .replaceLegSchedule, .replaceStaySchedule, .replaceActivitySchedule, .restoreItineraryItem:
            true
        case .setLegScheduledAt, .setTransportMode, .setReservationStatus, .setBookingService,
             .setBaggagePresence, .addBag, .setBagDimensions, .setSeatPreference,
             .updateReservationDetails, .updateScopedReservationStatus,
             .upsertNote, .removeNote, .addAttachment, .renameAttachment, .removeAttachment,
             .addSavedPlace, .removeSavedPlace, .cacheConnectorEstimate, .setDaySubtitle:
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
