import Foundation
import Testing
@testable import BulletGO

@MainActor
struct ItineraryPresentationTests {
    @Test func undatedTripKeepsASingleJourneySection() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let sections = ItineraryDayComposer.sections(for: trip)
        #expect(sections.count == 1)
        #expect(sections[0].rows.count == 6)
        #expect(sections[0].rows[0].title == "Tokyo → Kyoto")
    }

    @Test func datedItemsSplitUnscheduledAndDays() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let now = EngineTestSupport.now
        let dated = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 2))
        let leg = try ItineraryItemFactory.makeLeg(origin: "Tokyo", destination: "Osaka", scheduledAt: dated, at: now)
        let activity = try ItineraryItemFactory.makeActivity(title: "USJ", place: "Osaka", at: now)
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: now)
        let sections = ItineraryDayComposer.sections(for: trip)
        let october2 = try LocalDate(year: 2026, month: 10, day: 2)
        #expect(sections[0].id == .unscheduled)
        #expect(sections[0].rows.contains { $0.title == "USJ" })
        #expect(sections.contains { $0.id == .day(october2) })
    }
}

@MainActor
struct ItineraryDraftTests {
    @Test func deterministicExtractorCapturesTokyoOsakaAndLuggage() async throws {
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let extractor = LocalDeterministicItineraryDraftExtractor()
        let draft = try await extractor.extract(
            "October 2 morning, Tokyo to Osaka by Shinkansen. Large suitcase.",
            scope: .trip,
            trip: trip
        )
        #expect(draft.items.contains { $0.kind == .leg && $0.origin == "Tokyo" && $0.destination == "Osaka" })
        #expect(draft.items.contains { $0.kind == .baggageHint })
        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        #expect(mutations.contains { if case .addLeg = $0 { return true }; return false })
    }

    @Test func japaneseExtractorCapturesTokyoOsakaWithoutInventingReservation() async throws {
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let extractor = LocalDeterministicItineraryDraftExtractor()
        let draft = try await extractor.extract(
            "10月2日の朝、東京から大阪へ新幹線。大きい荷物がある。",
            scope: .trip,
            trip: trip
        )
        #expect(draft.items.contains { $0.kind == .leg && $0.origin == "Tokyo" && $0.destination == "Osaka" })
        #expect(draft.items.contains { $0.kind == .baggageHint })
        #expect(!draft.items.contains { $0.kind == .leg && $0.baggageHint != nil })
        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        #expect(!mutations.contains { if case .setReservationStatus = $0 { return true }; return false })
        #expect(!mutations.contains { if case .setBagDimensions = $0 { return true }; return false })
    }

    @Test func extractionDoesNotSaveUntilConfirm() async throws {
        let repository = InMemoryTripRepository()
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let session = TripSessionModel(store: store)
        await session.load()
        let draft = try await session.extractItineraryDraft(
            "October 2 morning, Tokyo to Osaka by Shinkansen. Large suitcase.",
            scope: .trip,
            trip: trip
        )
        #expect(!draft.items.isEmpty)
        let loaded = try await store.fetch(id: trip.id)
        #expect(loaded?.legs.isEmpty == true)

        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        _ = await session.process(.applyMutations(mutations))
        #expect(session.trip?.legs.contains { $0.origin.value == "Tokyo" && $0.destination.value == "Osaka" } == true)
    }

    @Test func validatorDropsItemsWithoutASourceQuote() {
        let draft = ProposedItineraryDraft(
            tripName: nil,
            startDate: nil,
            endDate: nil,
            items: [
                ProposedItineraryItem(
                    kind: .leg,
                    origin: "Tokyo",
                    destination: "Hakata",
                    place: nil,
                    title: nil,
                    date: nil,
                    time: nil,
                    transport: nil,
                    checkIn: nil,
                    checkOut: nil,
                    baggageHint: nil,
                    sourceQuote: "not in the source",
                    confidence: .low
                )
            ],
            unresolved: []
        )
        let validated = ItineraryDraftValidator.validated(draft, source: "Tokyo to Osaka")
        #expect(validated.items.isEmpty)
        #expect(!validated.unresolved.isEmpty)
    }
}
