import Foundation

nonisolated enum ImpactAnalyzer {
    static func analyze(_ mutation: TripMutation) -> (kind: ChangeEventKind, assessment: ImpactAssessment) {
        switch mutation {
        case .setTripName, .setTripStartDate, .setTripEndDate,
             .addLeg, .updateLegOrigin, .updateLegDestination, .unscheduleLeg, .removeLeg,
             .addStay, .updateStayPlace, .updateStayCheckIn, .updateStayCheckOut, .unscheduleStay, .removeStay,
             .addActivity, .updateActivityTitle, .updateActivityPlace, .updateActivityScheduledAt, .unscheduleActivity, .removeActivity,
             .moveTimelineItem:
            (
                .itineraryChanged,
                ImpactAssessment(level: .medium, targetLegs: [], changedPaths: [.trip(.timeline)])
            )
        case .setLegScheduledAt(let legID, _):
            (
                .dateChanged,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .scheduledAt)]
                )
            )
        case .setTransportMode(let legID, _):
            (
                .transportChanged,
                ImpactAssessment(
                    level: .high,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .transportMode)]
                )
            )
        case .setReservationStatus(let legID, _, _):
            (
                .reservationUpdated,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .reservation)]
                )
            )
        case .setBookingService(let legID, _):
            (
                .reservationUpdated,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .reservation)]
                )
            )
        case .setBaggagePresence(let legID, _, _):
            (
                .other,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .baggagePresence)]
                )
            )
        case .addBag(let legID, _):
            (
                .luggageAdded,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .bagIDs)]
                )
            )
        case .setBagDimensions(let bagID, _):
            (
                .other,
                ImpactAssessment(
                    level: .low,
                    targetLegs: [],
                    changedPaths: [.bag(bagID, .dimensions)]
                )
            )
        case .setSeatPreference(let legID, _):
            (
                .other,
                ImpactAssessment(
                    level: .low,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .seatPreference)]
                )
            )
        }
    }
}

nonisolated struct ImpactAssessment: Hashable, Sendable {
    var level: ChangeImpactLevel
    var targetLegs: [LegID]
    var changedPaths: [DomainPath]
}
