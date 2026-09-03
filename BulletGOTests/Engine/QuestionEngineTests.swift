import Foundation
import Testing
@testable import BulletGO

@MainActor
struct QuestionEngineTests {
    @Test func asksDateFirstOnEmptyFocusLeg() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let question = QuestionEngine.nextQuestion(in: trip, catalog: try EngineTestSupport.catalog())
        #expect(question?.id == .legDate)
    }

    @Test func inferredTransportCountsAsMissing() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let date = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
        trip = try TripMutationApplier.apply(.setLegScheduledAt(trip.legs[0].id, date), to: trip, at: EngineTestSupport.now)
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.transportMode = try Slot.inferred(value: .shinkansen, updatedAt: EngineTestSupport.now)
        }
        let question = QuestionEngine.nextQuestion(in: trip, catalog: try EngineTestSupport.catalog())
        #expect(question?.id == .transport)
    }

    @Test func skippedLuggageIsNotImmediatelyReasked() throws {
        let catalog = try EngineTestSupport.catalog()
        var trip = try PolicyScenarioSupport.trip(
            reservation: .booked,
            service: .smartEX,
            baggagePresence: nil,
            bags: []
        )
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.baggagePresence = try Slot.skipped(updatedAt: EngineTestSupport.now)
        }
        let question = QuestionEngine.nextQuestion(in: trip, catalog: catalog)
        #expect(question?.id != .luggagePresence)
        #expect(question?.id != .baggageDimensions)
    }

    @Test func serviceQuestionRequiresNotBookedReservation() throws {
        let catalog = try EngineTestSupport.catalog()
        let notBooked = try PolicyScenarioSupport.trip(reservation: .notBooked, baggagePresence: nil, bags: [])
        #expect(QuestionEngine.nextQuestion(in: notBooked, catalog: catalog)?.id == .selectService)

        let booked = try PolicyScenarioSupport.trip(reservation: .booked, baggagePresence: nil, bags: [])
        #expect(QuestionEngine.nextQuestion(in: booked, catalog: catalog)?.id == .luggagePresence)
    }

    @Test func dimensionsQuestionIsJITWhenPolicyNeedsInformation() throws {
        let catalog = try EngineTestSupport.catalog()
        let withLuggage = try PolicyScenarioSupport.trip(
            reservation: .booked,
            bags: [(PolicyScenarioSupport.bagA, nil)]
        )
        #expect(QuestionEngine.nextQuestion(in: withLuggage, catalog: catalog)?.id != .baggageDimensions)

        let evaluated = try ShinkansenBaggageRuleEngine.evaluate(
            withLuggage,
            pack: EngineTestSupport.pack(),
            at: EngineTestSupport.now
        )
        #expect(QuestionEngine.nextQuestion(in: evaluated, catalog: catalog)?.id == .baggageDimensions)
    }
}
