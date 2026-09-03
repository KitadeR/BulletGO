#if DEBUG
import Foundation

enum PreviewTrips {
    static let reference: Trip = {
        do {
            return try ReferenceTripFactory(now: { Date(timeIntervalSince1970: 1_788_393_600) }).makeReferenceTrip()
        } catch {
            preconditionFailure("Failed to make preview trip: \(error)")
        }
    }()

    static let withComingUpAndRemembered: Trip = {
        do {
            let now = Date(timeIntervalSince1970: 1_788_393_600)
            var trip = try ReferenceTripFactory(now: { now }).makeReferenceTrip()
            trip = try TripMutationApplier.apply(
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
                to: trip,
                at: now
            )
            let focus = trip.legs[0].id
            trip.tasks = [
                previewTask(contentKey: ActionPurpose.captureDimensions, importance: .required, scope: focus),
                previewTask(contentKey: ActionPurpose.selectBookingMethod, importance: .important, scope: focus),
                previewTask(contentKey: ActionPurpose.reserveOversizedSeat, importance: .recommended, scope: focus),
                previewTask(contentKey: ActionPurpose.verifyReservationMeetsBaggage, importance: .optional, scope: focus),
            ]
            return trip
        } catch {
            preconditionFailure("Failed to make remembered preview trip: \(error)")
        }
    }()

    private static func previewTask(
        contentKey: String,
        importance: TaskImportance,
        scope: LegID
    ) -> TripTask {
        TripTask(
            id: TaskID(),
            contentKey: contentKey,
            type: .check,
            state: .notStarted,
            importance: importance,
            relevantPhases: [.planning, .booking],
            deadline: nil,
            dependencies: [],
            evidence: .none,
            scope: .leg(scope),
            relatedActionID: nil,
            relatedPolicyID: .jrShinkansenOversizedBaggage,
            relatedGuideID: nil,
            completionCondition: .userConfirmsDone
        )
    }
}
#endif
