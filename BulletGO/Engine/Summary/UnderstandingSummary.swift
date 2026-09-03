import Foundation

nonisolated enum UnderstandingSummaryValue: Hashable, Sendable {
    case scheduledMoment(ScheduledMoment)
    case transportMode(TransportMode)
    case reservationStatus(ReservationStatus)
    case bookingService(BookingService)
    case baggagePresence(BaggagePresence)
    case seatPreference(SeatPreference)
    case baggageDimensions(BaggageDimensions)
}

nonisolated struct UnderstandingSummaryItem: Hashable, Sendable {
    var contentKey: String
    var scope: DomainScope
    var path: DomainPath
    var value: UnderstandingSummaryValue?
    var relatedQuestionID: QuestionID?
    var relatedDecisionPointID: DecisionPointID?
}

nonisolated struct UnderstandingSummary: Hashable, Sendable {
    var confirmed: [UnderstandingSummaryItem]
    var deferred: [UnderstandingSummaryItem]
    var unconfirmed: [UnderstandingSummaryItem]
}
