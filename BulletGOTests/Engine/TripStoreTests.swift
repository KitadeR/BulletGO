import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripStoreTests {
    @Test func successfulCommandSavesUpdatedTrip() async throws {
        let repository = InMemoryTripRepository()
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let result = try await store.process(
            tripID: trip.id,
            command: .answerQuestion(.transport, .choice("shinkansen"))
        )
        #expect(result.updatedTrip.legs[0].transportMode.value == .shinkansen)
        let saved = try await repository.fetch(id: trip.id)
        #expect(saved?.legs[0].transportMode.value == .shinkansen)
        #expect(await repository.saveCount == 2)
    }

    @Test func failedCommandLeavesPersistedTripUnchanged() async throws {
        let repository = InMemoryTripRepository()
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        await #expect(throws: EngineError.unknownQuestion("q_missing")) {
            _ = try await store.process(
                tripID: trip.id,
                command: .answerQuestion(QuestionID(rawValue: "q_missing"), .skip)
            )
        }
        let saved = try await repository.fetch(id: trip.id)
        #expect(saved == trip)
        #expect(await repository.saveCount == 1)
    }

    @Test func referenceTripOnlyEvaluatesFocusLeg() async throws {
        let repository = InMemoryTripRepository()
        let factory = ReferenceTripFactory(now: { EngineTestSupport.now })
        let trip = try factory.makeReferenceTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let result = try await store.process(
            tripID: trip.id,
            command: .answerQuestion(.transport, .choice("shinkansen"))
        )
        #expect(result.updatedTrip.legs[0].transportMode.value == .shinkansen)
        #expect(result.updatedTrip.legs[1].transportMode.status == .unknown)
        #expect(result.updatedTrip.legs[2].policyEvaluations.isEmpty)
        #expect(result.updatedTrip.legs[1].policyEvaluations.isEmpty)
    }

    @Test func unknownDecisionPointDoesNotSave() async throws {
        let repository = InMemoryTripRepository()
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        await #expect(throws: EngineError.unknownDecisionPoint("unknownPoint")) {
            _ = try await store.process(
                tripID: trip.id,
                command: .reachDecisionPoint(DecisionPointID(rawValue: "unknownPoint"))
            )
        }
        let saved = try await repository.fetch(id: trip.id)
        #expect(saved == trip)
        #expect(await repository.saveCount == 1)
    }

    @Test func successfulBatchSavesOnceAndLeavesOtherLegsUntouched() async throws {
        let repository = InMemoryTripRepository()
        let trip = try DomainTestSupport.sampleTrip()
        let otherPreference = trip.legs[1].seatPreference
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let result = try await store.process(
            tripID: trip.id,
            command: .applyMutations([
                .setTransportMode(trip.legs[0].id, .shinkansen),
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
            ])
        )
        #expect(result.updatedTrip.legs[0].seatPreference.value == .mountFujiView)
        #expect(result.updatedTrip.legs[1].seatPreference == otherPreference)
        #expect(result.updatedTrip.legs[1].policyEvaluations.isEmpty)
        #expect(await repository.saveCount == 2)
        let saved = try await repository.fetch(id: trip.id)
        #expect(saved?.legs[0].seatPreference.value == .mountFujiView)
        #expect(saved?.legs[1].seatPreference == otherPreference)
    }

    @Test func fetchAllAndFetchDoNotSave() async throws {
        let repository = InMemoryTripRepository()
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let all = try await store.fetchAll()
        let fetched = try await store.fetch(id: trip.id)
        #expect(all.map(\.id) == [trip.id])
        #expect(fetched == trip)
        #expect(await repository.saveCount == 1)
    }
}
