import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TimelinePresentationTests {
    @Test func comingUpKeepsTaskOrderThenAppendsDeferredRemembered() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let first = makeTask(ActionPurpose.captureDimensions, importance: .required, scope: focus)
        let second = makeTask(ActionPurpose.selectBookingMethod, importance: .important, scope: focus)
        let third = makeTask(ActionPurpose.reserveOversizedSeat, importance: .recommended, scope: focus)
        let nextTask = makeTask(ActionPurpose.verifyReservationMeetsBaggage, importance: .optional, scope: focus)
        trip.tasks = [first, second, third, nextTask]
        trip = try TripMutationApplier.apply(
            .setSeatPreference(focus, .mountFujiView),
            to: trip,
            at: EngineTestSupport.now
        )

        let items = TimelineNextComposer.items(for: trip)
        #expect(items.count == 2)
        #expect(items[0].kind == .task(nextTask.id))
        #expect(items[0].destination == .taskDetail(trip.id, nextTask.id))
        guard case .remembered(let remembered) = items[1].kind else {
            Issue.record("Expected remembered Coming Up row")
            return
        }
        #expect(remembered.contentKey == DeferredPresentationProjector.seatPreferenceContentKey)
        #expect(items[1].destination == .legDetail(trip.id, focus))
        #expect(items[1].content.title.key == "Mt. Fuji view seat")
        #expect(items[1].content.systemImage == "bookmark")
    }

    @Test func rememberedIsScopedToTheSelectedLeg() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip = try TripMutationApplier.apply(
            .setSeatPreference(trip.legs[0].id, .mountFujiView),
            to: trip,
            at: EngineTestSupport.now
        )
        let focusItems = TimelineNextComposer.rememberedItems(for: trip, legID: trip.legs[0].id)
        let otherItems = TimelineNextComposer.rememberedItems(for: trip, legID: trip.legs[1].id)
        #expect(focusItems.count == 1)
        #expect(otherItems.isEmpty)
        #expect(DeferredPresentationProjector.snapshot(for: trip, legID: trip.legs[1].id).remembered.isEmpty)
    }

    @Test func savingPreferenceShowsComingUpAndRemembered() throws {
        let brain = try EngineTestSupport.brain()
        let trip = try DomainTestSupport.sampleTrip()
        let result = try brain.process(
            trip: trip,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        )
        let comingUp = TimelineNextComposer.items(for: result.updatedTrip)
        let remembered = TimelineNextComposer.rememberedItems(
            for: result.updatedTrip,
            legID: result.updatedTrip.legs[0].id
        )
        #expect(comingUp.count == 1)
        #expect(remembered.count == 1)
        #expect(result.displaySnapshot.now.isEmpty)
        #expect(result.updatedTrip.tasks.isEmpty)
    }

    @Test func seatSelectionLeavesRememberedAndClearsComingUp() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        trip = try brain.process(
            trip: trip,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        ).updatedTrip
        let revealed = try brain.process(trip: trip, command: .reachDecisionPoint(.seatSelection))
        let comingUp = TimelineNextComposer.items(for: revealed.updatedTrip)
        let remembered = TimelineNextComposer.rememberedItems(
            for: revealed.updatedTrip,
            legID: revealed.updatedTrip.legs[0].id
        )
        #expect(comingUp.isEmpty)
        #expect(remembered.count == 1)
        #expect(remembered[0].content.subtitle?.key == "Saved for this journey.")
    }

    @Test func unknownContentKeysUseSafeFallbackCopy() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let unknownRemembered = DeferredPresentationItem(
            contentKey: "mystery.unknown",
            scope: .leg(trip.legs[0].id),
            field: .leg(trip.legs[0].id, .seatPreference),
            decisionPoint: .seatSelection,
            presentationTiming: .deferred(until: .seatSelection)
        )
        let remembered = TripContentResolver.remembered(unknownRemembered, trip: trip)
        #expect(remembered.title.key == "Saved detail")
        #expect(remembered.subtitle?.key == "We’ll bring this up at the right time.")
        #expect(remembered.title.key.contains("mystery.unknown") == false)

        let unknownTask = TripContentResolver.task(contentKey: "mystery.task")
        #expect(unknownTask.title.key == "Something to check")
        #expect(unknownTask.title.key.contains("mystery.task") == false)
    }

    @Test func nowUsesSnapshotNowOnlyWhenSetupIsReady() throws {
        let catalog = try EngineTestSupport.catalog()
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        trip = try brain.process(
            trip: trip,
            command: .applyMutations([
                .setTransportMode(trip.legs[0].id, .shinkansen),
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
            ])
        ).updatedTrip
        let afterInput = TimelineNowComposer.items(for: trip, catalog: catalog)
        #expect(afterInput.count == 1)
        guard case .resume = afterInput[0].kind else {
            Issue.record("Expected a resume card before setup is confirmed")
            return
        }
        #expect(TaskDisplayPipeline.snapshot(for: trip).now.isEmpty)

        let moment = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
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

        let ready = TimelineNowComposer.items(for: trip, catalog: catalog)
        let snapshot = TaskDisplayPipeline.snapshot(for: trip)
        #expect(ready.map(\.kind) == snapshot.now.map(TimelineNowKind.task))
        #expect(snapshot.now.count >= 1)
        #expect(ready.allSatisfy { item in
            if case .task = item.kind { return true }
            return false
        })
        #expect(ready.contains { item in
            if case .resume = item.kind { return true }
            return false
        } == false)
    }

    @Test func skippedSetupKeepsResumeInsteadOfNow() throws {
        let catalog = try EngineTestSupport.catalog()
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        trip = try brain.process(
            trip: trip,
            command: .applyMutation(.setTransportMode(trip.legs[0].id, .shinkansen))
        ).updatedTrip
        let moment = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
        trip = try brain.process(
            trip: trip,
            command: .answerQuestion(.legDate, .scheduledMoment(moment))
        ).updatedTrip
        trip = try brain.process(
            trip: trip,
            command: .answerQuestion(.ticketStatus, .choice("unsure"))
        ).updatedTrip
        let items = TimelineNowComposer.items(for: trip, catalog: catalog)
        #expect(items.count == 1)
        guard case .resume = items[0].kind else {
            Issue.record("Expected resume after skipped booking status")
            return
        }
    }

    @Test func timelineRowsFollowTripOrderAndKeepActivitiesDisplayOnly() throws {
        let trip = try ReferenceTripFactory(now: { EngineTestSupport.now }).makeReferenceTrip()
        let rows = TimelineRowComposer.rows(for: trip)
        #expect(rows.map(\.title) == [
            "Tokyo → Kyoto",
            "Kinkaku-ji",
            "Kyoto → Osaka",
            "Dotonbori",
            "Osaka → Hakata",
            "Hakata sightseeing",
        ])
        #expect(rows[0].isCurrent)
        #expect(rows[0].isLeg)
        #expect(rows[0].destination == .legDetail(trip.id, ReferenceTripIdentity.tokyoKyoto))
        #expect(rows[1].destination == .activityDetail(trip.id, ReferenceTripIdentity.kinkakuji))
        #expect(rows[1].isLeg == false)
        if case .localized(let resource) = rows[0].subtitle {
            #expect(resource.key == "Not decided yet")
        } else {
            Issue.record("Expected localized transport subtitle")
        }
        if case .verbatim(let place) = rows[1].subtitle {
            #expect(place == "Kyoto")
        } else {
            Issue.record("Expected verbatim activity place")
        }
    }

    private func makeTask(
        _ key: String,
        importance: TaskImportance,
        scope: LegID
    ) -> TripTask {
        TripTask(
            id: TaskID(),
            contentKey: key,
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
