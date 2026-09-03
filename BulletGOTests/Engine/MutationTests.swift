import Foundation
import Testing
@testable import BulletGO

@MainActor
struct MutationTests {
    @Test func applyingDateMutationKeepsRevisionAndChangeEvent() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let original = trip.legs[0].scheduledAt
        let moment = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
        let updated = try TripMutationApplier.apply(
            .setLegScheduledAt(trip.legs[0].id, moment),
            to: trip,
            at: EngineTestSupport.now.addingTimeInterval(10)
        )
        #expect(updated.legs[0].scheduledAt.status == .confirmed)
        #expect(updated.legs[0].scheduledAt.source == .userStated)
        #expect(updated.legs[0].scheduledAt.revisions.count == original.revisions.count + 1)
        #expect(updated.changeEvents.last?.kind == .dateChanged)
        #expect(updated.updatedAt == EngineTestSupport.now.addingTimeInterval(10))
    }

    @Test func answeringInferredTransportPromotesWithUserStatedNotAI() throws {
        var trip = try DomainTestSupport.sampleTrip()
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.transportMode = try Slot.inferred(value: .airplane, updatedAt: EngineTestSupport.now)
        }
        let mutations = try QuestionAnswerMapper.mutations(
            for: try EngineTestSupport.catalog().spec(id: .transport)!,
            answer: .choice("shinkansen"),
            trip: trip
        )
        let updated = try TripMutationApplier.apply(mutations[0], to: trip, at: EngineTestSupport.now)
        #expect(updated.legs[0].transportMode.value == .shinkansen)
        #expect(updated.legs[0].transportMode.status == .confirmed)
        #expect(updated.legs[0].transportMode.source == .userStated)
        #expect(updated.legs[0].transportMode.revisions.last?.source == .aiInferred)
    }

    @Test func luggageYesAddsABagWithJustInTimeDimensions() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let spec = try #require(EngineTestSupport.catalog().spec(id: .luggagePresence))
        let mutations = try QuestionAnswerMapper.mutations(for: spec, answer: .choice("yes"), trip: trip)
        var updated = trip
        for mutation in mutations {
            updated = try TripMutationApplier.apply(mutation, to: updated, at: EngineTestSupport.now)
        }
        #expect(updated.legs[0].baggagePresence.value == .yes)
        #expect(updated.baggageInventory.count == 1)
        #expect(updated.baggageInventory[0].dimensions.collectionTiming == .justInTime(.baggagePolicyEvaluation))
        #expect(updated.changeEvents.map(\.kind).contains(.luggageAdded))
    }

    @Test func impactAnalyzerMarksTransportChangeAsHigh() {
        let legID = LegID()
        let impact = ImpactAnalyzer.analyze(.setTransportMode(legID, .airplane))
        #expect(impact.kind == .transportChanged)
        #expect(impact.assessment.level == .high)
        #expect(impact.assessment.targetLegs == [legID])
    }
}
