import Foundation
import Testing
@testable import BulletGO

@MainActor
struct PolicyEngineTests {
    @Test func boundsMatchOfficialJRThresholds() throws {
        let pack = try EngineTestSupport.pack()
        #expect(pack.requirement(forTotalCM: 160) == .notRequired)
        #expect(pack.requirement(forTotalCM: 161) == .required)
        #expect(pack.requirement(forTotalCM: 250) == .required)
        #expect(pack.requirement(forTotalCM: 251) == .notAllowed)
    }

    @Test func missingDimensionsAskForMoreInformation() throws {
        let trip = try PolicyScenarioSupport.trip(bags: [(PolicyScenarioSupport.bagA, nil)])
        let evaluated = try ShinkansenBaggageRuleEngine.evaluate(
            trip,
            pack: EngineTestSupport.pack(),
            at: EngineTestSupport.now
        )
        let evaluation = try #require(evaluated.legs[0].policyEvaluations.first)
        #expect(evaluation.status == .needsMoreInformation)
        #expect(evaluation.missingFieldPaths == [.bag(PolicyScenarioSupport.bagA, .dimensions)])
        #expect(evaluation.bagID == PolicyScenarioSupport.bagA)
    }

    @Test func nonShinkansenMarksExistingEvaluationStale() throws {
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31))]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: try EngineTestSupport.pack(), at: EngineTestSupport.now)
        let originalID = try #require(trip.legs[0].policyEvaluations.first?.id)
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.transportMode = try Slot.confirmed(value: .airplane, source: .userStated, updatedAt: EngineTestSupport.now)
        }
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: try EngineTestSupport.pack(), at: EngineTestSupport.now)
        #expect(trip.legs[0].policyEvaluations[0].id == originalID)
        #expect(trip.legs[0].policyEvaluations[0].status == .stale)
    }

    @Test func missingSelectedBagNeedsBagIDs() throws {
        let trip = try PolicyScenarioSupport.trip(bags: [])
        let evaluated = try ShinkansenBaggageRuleEngine.evaluate(
            trip,
            pack: try EngineTestSupport.pack(),
            at: EngineTestSupport.now
        )
        #expect(evaluated.legs[0].policyEvaluations[0].status == .needsMoreInformation)
        #expect(evaluated.legs[0].policyEvaluations[0].missingFieldPaths == [.leg(trip.legs[0].id, .bagIDs)])
    }

    @Test func multipleBagsKeepStableIDsAndIgnorePerceivedSize() throws {
        let small = try PolicyScenarioSupport.dimensions(length: 50, width: 40, height: 30)
        let oversized = try PolicyScenarioSupport.dimensions(length: 100, width: 80, height: 70)
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, small), (PolicyScenarioSupport.bagB, oversized)]
        )
        try trip.updateBag(id: PolicyScenarioSupport.bagA) { bag in
            bag.perceivedSize = try Slot.confirmed(value: .large, source: .userStated, updatedAt: EngineTestSupport.now)
        }
        let pack = try EngineTestSupport.pack()
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        let firstIDs = trip.legs[0].policyEvaluations.map(\.id)
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        #expect(trip.legs[0].policyEvaluations.map(\.id) == firstIDs)
        #expect(trip.legs[0].policyEvaluations[0].resultFields[pack.resultKey] == "not_required")
        #expect(trip.legs[0].policyEvaluations[1].resultFields[pack.resultKey] == "required")
    }

    @Test func doesNotTouchOtherLegs() throws {
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31))]
        )
        let otherEval = PolicyEvaluation(
            id: PolicyEvaluationID(),
            policyID: .jrShinkansenOversizedBaggage,
            policyVersion: "1",
            effectiveDate: nil,
            scope: .leg(trip.legs[1].id),
            bagID: nil,
            status: .unevaluated,
            missingFieldPaths: [],
            resultFields: [:],
            evaluatedAt: nil
        )
        try trip.updateLeg(id: trip.legs[1].id) { $0.policyEvaluations = [otherEval] }
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: try EngineTestSupport.pack(), at: EngineTestSupport.now)
        #expect(trip.legs[1].policyEvaluations == [otherEval])
        #expect(!trip.legs[0].policyEvaluations.isEmpty)
    }
}
