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

    static let readyForNow: Trip = {
        do {
            let now = Date(timeIntervalSince1970: 1_788_393_600)
            let catalog = try QuestionCatalogLoader.loadProduction(from: .main)
            let pack = try PackLoader.loadProduction(from: .main)
            let brain = TripBrain(catalog: catalog, pack: pack, clock: .fixed(now))
            var trip = try ReferenceTripFactory(now: { now }).makeReferenceTrip()
            let focus = ReferenceTripIdentity.tokyoKyoto
            trip = try brain.process(
                trip: trip,
                command: .applyMutations([
                    .setTransportMode(focus, .shinkansen),
                    .setSeatPreference(focus, .mountFujiView),
                ])
            ).updatedTrip
            guard let start = trip.startDate.value else {
                preconditionFailure("Reference trip is missing a start date.")
            }
            let moment = try ScheduledMoment(
                date: start,
                timeZoneIdentifier: "Asia/Tokyo"
            )
            trip = try brain.process(
                trip: trip,
                command: .answerQuestion(.legDate, .scheduledMoment(moment))
            ).updatedTrip
            trip = try brain.process(
                trip: trip,
                command: .answerQuestion(.ticketStatus, .choice("notBooked"))
            ).updatedTrip
            trip = try brain.process(
                trip: trip,
                command: .answerQuestion(.luggagePresence, .choice("yes"))
            ).updatedTrip
            return trip
        } catch {
            preconditionFailure("Failed to make ready-now preview trip: \(error)")
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
