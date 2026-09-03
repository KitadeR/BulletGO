import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripSessionModelTests {
    @Test func loadAfterBootstrapSelectsReferenceTrip() async throws {
        let persistence = try PersistenceStack.inMemory()
        try await persistence.bootstrap()
        let session = TripSessionModel(
            store: TripStore(repository: persistence.repository, brain: try EngineTestSupport.brain())
        )
        await session.load()
        #expect(session.loadState == .loaded)
        #expect(session.trip?.id == ReferenceTripIdentity.trip)
        #expect(session.trip?.legs.map(\.origin.value) == ["Tokyo", "Kyoto", "Osaka"])
        #expect(session.trip?.legs.map(\.destination.value) == ["Kyoto", "Osaka", "Hakata"])
    }

    @Test func loadEmptyWhenNoTrips() async throws {
        let session = TripSessionModel(
            store: TripStore(repository: InMemoryTripRepository(), brain: try EngineTestSupport.brain())
        )
        await session.load()
        #expect(session.loadState == .empty)
        #expect(session.trip == nil)
    }

    @Test func loadFailedThenRetryKeepsErrorUntilStoreRecovers() async throws {
        let session = TripSessionModel(
            store: TripStore(repository: FailingTripRepository(), brain: try EngineTestSupport.brain())
        )
        await session.load()
        #expect(session.loadState == .failed)
        #expect(session.trip == nil)
        await session.retry()
        #expect(session.loadState == .failed)
    }

    @Test func applyUpdatesSessionFromBrainResult() async throws {
        let repository = InMemoryTripRepository()
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let session = TripSessionModel(store: store)
        await session.load()
        let result = try await store.process(
            tripID: trip.id,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        )
        session.apply(result)
        #expect(session.loadState == .loaded)
        #expect(session.trip?.legs[0].seatPreference.value == .mountFujiView)
        #expect(session.lastBrainResult?.deferredSnapshot.next.count == 1)
        #expect(session.lastBrainResult?.updatedTrip.id == trip.id)
    }
}
