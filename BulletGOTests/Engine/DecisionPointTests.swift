import Foundation
import Testing
@testable import BulletGO

@MainActor
struct DecisionPointTests {
    @Test func seatSelectionIsActiveOnlyWhenExplicitlyReached() throws {
        let trip = try PolicyScenarioSupport.trip()
        #expect(DecisionPointResolver.activePoints(in: trip).contains(.seatSelection) == false)
        #expect(
            DecisionPointResolver.activePoints(in: trip, reached: [.seatSelection]).contains(.seatSelection)
        )
    }

    @Test func baggagePolicyEvaluationFollowsMissingDimensions() throws {
        let unevaluated = try PolicyScenarioSupport.trip(
            reservation: .booked,
            bags: [(PolicyScenarioSupport.bagA, nil)]
        )
        #expect(DecisionPointResolver.needsBaggageDimensions(in: unevaluated) == false)

        let evaluated = try ShinkansenBaggageRuleEngine.evaluate(
            unevaluated,
            pack: EngineTestSupport.pack(),
            at: EngineTestSupport.now
        )
        #expect(DecisionPointResolver.needsBaggageDimensions(in: evaluated))
        #expect(DecisionPointResolver.activePoints(in: evaluated).contains(.baggagePolicyEvaluation))
    }

    @Test func unknownDecisionPointIsRejected() {
        #expect(throws: EngineError.unknownDecisionPoint("unknownPoint")) {
            try DecisionPointResolver.validate(DecisionPointID(rawValue: "unknownPoint"))
        }
    }
}
