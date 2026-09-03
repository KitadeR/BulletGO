import Foundation
import Testing
@testable import BulletGO

@MainActor
struct DeferredPresentationTests {
    @Test func savingFujiPreferenceDefersPresentationOnFocusLegOnly() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let focusID = trip.legs[0].id
        let updated = try TripMutationApplier.apply(
            .setSeatPreference(focusID, .mountFujiView),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(updated.legs[0].seatPreference.value == .mountFujiView)
        #expect(updated.legs[0].seatPreference.status == .confirmed)
        #expect(updated.legs[0].seatPreference.source == .userStated)
        #expect(updated.legs[0].seatPreference.presentationTiming == .deferred(until: .seatSelection))
        #expect(updated.legs[1].seatPreference.status == .unknown)
        #expect(updated.legs[2].seatPreference.status == .unknown)
        #expect(updated.changeEvents.last?.changedPaths == [.leg(focusID, .seatPreference)])
    }

    @Test func deferredPreferenceAppearsInRememberedAndNextButNotNowOrTasks() throws {
        let brain = try EngineTestSupport.brain()
        let trip = try DomainTestSupport.sampleTrip()
        let result = try brain.process(
            trip: trip,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        )
        #expect(result.deferredSnapshot.remembered.count == 1)
        #expect(result.deferredSnapshot.next.count == 1)
        #expect(result.deferredSnapshot.remembered[0].contentKey == "leg.seatPreference")
        #expect(result.deferredSnapshot.next[0].decisionPoint == .seatSelection)
        #expect(result.displaySnapshot.now.isEmpty)
        #expect(result.updatedTrip.tasks.isEmpty)
        #expect(result.updatedTrip.tasks.map(\.contentKey).contains("leg.seatPreference") == false)
    }

    @Test func bookingPhaseAndReevaluateDoNotRevealDeferredPreference() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        trip = try brain.process(
            trip: trip,
            command: .applyMutations([
                .setTransportMode(trip.legs[0].id, .shinkansen),
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
            ])
        ).updatedTrip
        #expect(trip.legs[0].phase == .booking)
        #expect(trip.legs[0].seatPreference.presentationTiming == .deferred(until: .seatSelection))

        let reevaluated = try brain.process(trip: trip, command: .reevaluate)
        #expect(reevaluated.updatedTrip.legs[0].seatPreference.presentationTiming == .deferred(until: .seatSelection))
        #expect(reevaluated.understandingSummary == nil)
        #expect(reevaluated.deferredSnapshot.next.count == 1)
    }

    @Test func explicitSeatSelectionRevealsFocusLegOnlyAndIsIdempotent() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        try trip.updateLeg(id: trip.legs[1].id) { leg in
            leg.seatPreference = try Slot.confirmed(
                value: .mountFujiView,
                source: .userStated,
                presentationTiming: .deferred(until: .seatSelection),
                updatedAt: EngineTestSupport.now
            )
        }
        trip = try brain.process(
            trip: trip,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        ).updatedTrip
        let first = try brain.process(trip: trip, command: .reachDecisionPoint(.seatSelection))
        #expect(first.updatedTrip.legs[0].seatPreference.presentationTiming == .immediate)
        #expect(first.updatedTrip.legs[1].seatPreference.presentationTiming == .deferred(until: .seatSelection))
        #expect(first.deferredSnapshot.next.isEmpty)
        #expect(first.deferredSnapshot.remembered.count == 1)
        #expect(first.understandingSummary == nil)
        let revisionCount = first.updatedTrip.legs[0].seatPreference.revisions.count

        let second = try brain.process(
            trip: first.updatedTrip,
            command: .reachDecisionPoint(.seatSelection)
        )
        #expect(second.updatedTrip.legs[0].seatPreference.revisions.count == revisionCount)
        #expect(second.updatedTrip.legs[0].seatPreference.updatedAt == first.updatedTrip.legs[0].seatPreference.updatedAt)
        #expect(second.updatedTrip.changeEvents.count == first.updatedTrip.changeEvents.count)
    }

    @Test func snapshotForLegDoesNotUseFocusLegWhenAnotherLegIsSelected() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        trip = try brain.process(
            trip: trip,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        ).updatedTrip
        let focusSnapshot = DeferredPresentationProjector.snapshot(for: trip)
        let otherSnapshot = DeferredPresentationProjector.snapshot(for: trip, legID: trip.legs[1].id)
        #expect(focusSnapshot.remembered.count == 1)
        #expect(focusSnapshot.next.count == 1)
        #expect(otherSnapshot == .empty)
    }
}
