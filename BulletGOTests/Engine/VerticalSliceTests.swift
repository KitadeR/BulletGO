import Foundation
import Testing
@testable import BulletGO

@MainActor
struct VerticalSliceTests {
    @Test func referencePathCreatesNowThenRecalculatesAt161() async throws {
        let repository = InMemoryTripRepository()
        let factory = ReferenceTripFactory(now: { EngineTestSupport.now })
        let trip = try factory.makeReferenceTrip()
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let focus = ReferenceTripIdentity.tokyoKyoto

        var result = try await store.process(
            tripID: trip.id,
            command: .applyMutations([
                .setTransportMode(focus, .shinkansen),
                .setSeatPreference(focus, .mountFujiView),
            ])
        )
        #expect(result.understandingSummary?.confirmed.map(\.contentKey) == ["leg.transportMode"])
        #expect(result.understandingSummary?.deferred.map(\.contentKey) == ["leg.seatPreference"])
        #expect(result.displaySnapshot.now.isEmpty)
        #expect(result.updatedTrip.tasks.isEmpty)
        #expect(QuestionEngine.nextSetupQuestion(in: result.updatedTrip, catalog: try EngineTestSupport.catalog())?.id == .legDate)

        let moment = try ScheduledMoment(
            date: try #require(result.updatedTrip.startDate.value),
            timeZoneIdentifier: "Asia/Tokyo"
        )
        result = try await store.process(
            tripID: trip.id,
            command: .answerQuestion(.legDate, .scheduledMoment(moment))
        )
        result = try await store.process(
            tripID: trip.id,
            command: .answerQuestion(.ticketStatus, .choice("notBooked"))
        )
        result = try await store.process(
            tripID: trip.id,
            command: .answerQuestion(.luggagePresence, .choice("yes"))
        )

        let catalog = try EngineTestSupport.catalog()
        #expect(GuidanceProgressEvaluator.isReadyForNow(trip: result.updatedTrip, catalog: catalog))
        let nowKeys = result.displaySnapshot.now.compactMap { id in
            result.updatedTrip.tasks.first { $0.id == id }?.contentKey
        }
        #expect(Set(nowKeys).isSuperset(of: [
            ActionPurpose.captureDimensions,
            ActionPurpose.selectBookingMethod,
        ]))
        #expect(nowKeys.contains(where: { $0.contains("fuji") }) == false)
        #expect(result.nextQuestion?.id == .selectService)
        #expect(QuestionEngine.nextSetupQuestion(in: result.updatedTrip, catalog: catalog) == nil)

        let bagID = try #require(result.updatedTrip.legs[0].bagIDs.first)
        _ = bagID
        result = try await store.process(
            tripID: trip.id,
            command: .answerQuestion(
                .baggageDimensions,
                .dimensions(try BaggageDimensions(lengthCM: 80, widthCM: 40, heightCM: 41))
            )
        )
        let pack = try EngineTestSupport.pack()
        let evaluation = try #require(
            result.updatedTrip.legs[0].policyEvaluations.first { $0.status == .evaluated }
        )
        #expect(evaluation.resultFields[pack.resultKey] == "required")
        let afterKeys = Set(
            result.updatedTrip.tasks
                .filter { $0.state != .cancelled }
                .map(\.contentKey)
        )
        #expect(!afterKeys.contains(ActionPurpose.captureDimensions))
        #expect(afterKeys.contains(ActionPurpose.reserveOversizedSeat))
        #expect(result.updatedTrip.legs[0].seatPreference.value == .mountFujiView)
    }
}
