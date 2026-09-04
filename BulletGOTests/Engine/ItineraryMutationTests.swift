import Foundation
import Testing
@testable import BulletGO

@MainActor
struct ItineraryMutationTests {
    @Test func emptyTripIsValidAndPersists() async throws {
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        try trip.validate()
        #expect(trip.schemaVersion == 4)
        #expect(trip.legs.isEmpty)
        #expect(trip.stays.isEmpty)
        #expect(trip.timeline.isEmpty)
        #expect(trip.currentContext.focus == .none)

        let store = TripStore(repository: InMemoryTripRepository(), brain: try EngineTestSupport.brain())
        try await store.create(trip)
        let loaded = try await store.fetch(id: trip.id)
        #expect(loaded == trip)
    }

    @Test func addingLegStayAndActivityKeepsTimelineCoverage() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let now = EngineTestSupport.now
        let moment = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 2))
        let leg = try ItineraryItemFactory.makeLeg(origin: "Tokyo", destination: "Osaka", scheduledAt: moment, at: now)
        let stay = try ItineraryItemFactory.makeStay(place: "Osaka", checkIn: moment, at: now)
        let activity = try ItineraryItemFactory.makeActivity(title: "USJ", place: "Osaka", at: now)

        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: now)

        #expect(trip.timeline == [.leg(leg.id), .stay(stay.id), .activity(activity.id)])
        #expect(trip.currentContext.focus == .leg(leg.id))
        #expect(trip.changeEvents.last?.kind == .itineraryChanged)
    }

    @Test func removingFocusLegDropsItsTasksAndMovesFocus() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let removed = trip.legs[0].id
        let remaining = trip.legs[1].id
        trip.tasks = [
            TripTask(
                id: TaskID(),
                contentKey: ActionPurpose.captureDimensions,
                type: .check,
                state: .notStarted,
                importance: .required,
                relevantPhases: [.planning],
                deadline: nil,
                dependencies: [],
                evidence: .none,
                scope: .leg(removed),
                relatedActionID: nil,
                relatedPolicyID: nil,
                relatedGuideID: nil,
                completionCondition: .userConfirmsDone
            )
        ]
        let bag = Bag(
            id: BagID(),
            kind: try Slot.inferred(value: .suitcase, updatedAt: EngineTestSupport.now),
            userDescription: try Slot.unknown(updatedAt: EngineTestSupport.now),
            perceivedSize: try Slot.unknown(updatedAt: EngineTestSupport.now),
            dimensions: try Slot.unknown(updatedAt: EngineTestSupport.now),
            weightKilograms: try Slot.unknown(updatedAt: EngineTestSupport.now),
            createdAt: EngineTestSupport.now
        )
        trip.baggageInventory = [bag]
        trip.legs[0].bagIDs = [bag.id]

        let updated = try TripMutationApplier.apply(.removeLeg(removed), to: trip, at: EngineTestSupport.now)
        #expect(updated.legs.contains { $0.id == removed } == false)
        #expect(updated.timeline.contains(.leg(removed)) == false)
        #expect(updated.tasks.isEmpty)
        #expect(updated.baggageInventory.map(\.id) == [bag.id])
        #expect(updated.currentContext.focus == .leg(remaining))
    }

    @Test func moveTimelineItemChangesOrderNotDates() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let originalDate = trip.legs[0].scheduledAt
        let updated = try TripMutationApplier.apply(
            .moveTimelineItem(from: 0, to: 2),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(updated.timeline[0] == .activity(trip.activities[0].id))
        #expect(updated.timeline[1] == .leg(trip.legs[0].id))
        #expect(updated.legs[0].scheduledAt == originalDate)
    }

    @Test func unschedulingActivityClearsDateWithoutRemovingIt() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let activityID = trip.activities[0].id
        let moment = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 3))
        trip = try TripMutationApplier.apply(
            .updateActivityScheduledAt(activityID, moment),
            to: trip,
            at: EngineTestSupport.now
        )
        let updated = try TripMutationApplier.apply(
            .unscheduleActivity(activityID),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(updated.activities[0].scheduledAt.status == .unknown)
        #expect(updated.timeline.contains(.activity(activityID)))
    }

    @Test func stayRoundTripsThroughPersistence() async throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let stay = try ItineraryItemFactory.makeStay(
            place: "Kyoto",
            checkIn: try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        let store = TripStore(repository: InMemoryTripRepository(), brain: try EngineTestSupport.brain())
        try await store.create(trip)
        let loaded = try await store.fetch(id: trip.id)
        #expect(loaded?.stays.map(\.place.value) == ["Kyoto"])
        #expect(loaded?.timeline.contains(.stay(stay.id)) == true)
    }

    @Test func unmatchedTokyoOsakaBecomesANewLeg() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let draft = ProposedItineraryDraft(
            tripName: nil,
            startDate: nil,
            endDate: nil,
            items: [
                ProposedItineraryItem(
                    kind: .leg,
                    origin: "Tokyo",
                    destination: "Osaka",
                    place: nil,
                    title: nil,
                    date: "2026-10-02",
                    time: "morning",
                    transport: "shinkansen",
                    checkIn: nil,
                    checkOut: nil,
                    baggageHint: nil,
                    sourceQuote: "Tokyo to Osaka",
                    confidence: .high
                )
            ],
            unresolved: []
        )
        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        #expect(mutations.contains { if case .addLeg = $0 { return true }; return false })
        #expect(!trip.legs.contains { $0.origin.value == "Tokyo" && $0.destination.value == "Osaka" })
    }

    @Test func orphanLegFailsValidation() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.timeline.removeAll { $0 == .leg(trip.legs[0].id) }
        #expect(throws: TripValidationError.orphanItineraryItem) {
            try trip.validate()
        }
    }
}
