import Foundation
import Testing
import UniformTypeIdentifiers
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

    @Test func changingNonFocusLegRecalculatesOnlyThatLeg() async throws {
        let repository = InMemoryTripRepository()
        let factory = ReferenceTripFactory(now: { EngineTestSupport.now })
        let trip = try factory.makeReferenceTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let focusID = trip.legs[0].id
        let otherID = trip.legs[1].id
        #expect(trip.focusLegID == focusID)
        let result = try await store.process(
            tripID: trip.id,
            command: .applyMutation(.setTransportMode(otherID, .shinkansen))
        )
        #expect(result.updatedTrip.focusLegID == focusID)
        #expect(result.updatedTrip.legs[1].transportMode.value == .shinkansen)
        #expect(result.updatedTrip.legs[0].transportMode == trip.legs[0].transportMode)
        #expect(result.updatedTrip.legs[0].policyEvaluations == trip.legs[0].policyEvaluations)
        #expect(result.updatedTrip.legs[2].policyEvaluations == trip.legs[2].policyEvaluations)
        #expect(result.updatedTrip.legs[1].transportMode.value == .shinkansen)
    }

    @Test func attachmentSaveFailureDoesNotLeaveMetadata() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "BulletGO-attach-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let attachments = AttachmentStore(root: root)
        let trip = try DomainTestSupport.sampleTrip()
        let store = TripStore(
            repository: SaveFailingTripRepository(trip: trip),
            brain: try EngineTestSupport.brain(),
            attachments: attachments
        )
        await #expect(throws: EngineError.tripNotFound) {
            _ = try await store.importAttachment(
                tripID: trip.id,
                data: Data("photo".utf8),
                fileName: "photo.jpg",
                utType: .jpeg,
                scope: .trip
            )
        }
        let contents = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let leftover = contents.filter { url in
            let name = url.lastPathComponent
            guard name != ".trash", name != ".staging" else { return false }
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            return !children.isEmpty
        }
        #expect(leftover.isEmpty)
    }

    @Test func undoDeleteRestoresItemAtOriginalIndex() async throws {
        let repository = InMemoryTripRepository()
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let removed = try await store.processDetailed(
            tripID: trip.id,
            command: .applyMutation(.removeActivity(activity.id))
        )
        #expect(removed.brain.updatedTrip.activities.isEmpty)
        let restored = try await store.undo(receipt: removed.receipt)
        #expect(restored.updatedTrip.activities.contains { $0.id == activity.id })
        #expect(restored.updatedTrip.timeline.first == .activity(activity.id))
    }
}
