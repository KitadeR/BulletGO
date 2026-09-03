import Foundation
import Testing
@testable import BulletGO

@MainActor
struct UnderstandingSummaryTests {
    @Test func shinkansenAndFujiBatchClassifiesConfirmedDeferredAndUnconfirmed() throws {
        let brain = try EngineTestSupport.brain()
        let trip = try DomainTestSupport.sampleTrip()
        let result = try brain.process(
            trip: trip,
            command: .applyMutations([
                .setTransportMode(trip.legs[0].id, .shinkansen),
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
            ])
        )
        let summary = try #require(result.understandingSummary)
        #expect(summary.confirmed.map(\.contentKey) == ["leg.transportMode"])
        #expect(summary.confirmed[0].value == .transportMode(.shinkansen))
        #expect(summary.deferred.map(\.contentKey) == ["leg.seatPreference"])
        #expect(summary.deferred[0].value == .seatPreference(.mountFujiView))
        #expect(summary.deferred[0].relatedDecisionPointID == .seatSelection)
        #expect(summary.unconfirmed.map(\.contentKey) == [
            QuestionID.legDate.rawValue,
            QuestionID.ticketStatus.rawValue,
            QuestionID.luggagePresence.rawValue,
        ])
        #expect(summary.unconfirmed.contains { $0.contentKey == QuestionID.selectService.rawValue } == false)
        #expect(summary.unconfirmed.contains { $0.contentKey == QuestionID.baggageDimensions.rawValue } == false)
        #expect(result.nextQuestion?.id == .legDate)
    }

    @Test func reevaluateAndDecisionPointDoNotReturnSummary() throws {
        let brain = try EngineTestSupport.brain()
        let trip = try DomainTestSupport.sampleTrip()
        #expect(try brain.process(trip: trip, command: .reevaluate).understandingSummary == nil)
        #expect(
            try brain.process(trip: trip, command: .reachDecisionPoint(.seatSelection)).understandingSummary == nil
        )
    }
}
