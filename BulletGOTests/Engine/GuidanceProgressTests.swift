import Foundation
import Testing
@testable import BulletGO

@MainActor
struct GuidanceProgressTests {
    @Test func shinkansenAndFujiLeaveSetupQuestions() throws {
        let catalog = try EngineTestSupport.catalog()
        let brain = try EngineTestSupport.brain()
        let trip = try DomainTestSupport.sampleTrip()
        let updated = try brain.process(
            trip: trip,
            command: .applyMutations([
                .setTransportMode(trip.legs[0].id, .shinkansen),
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
            ])
        ).updatedTrip
        guard case .needsSetup(let question) = GuidanceProgressEvaluator.evaluate(trip: updated, catalog: catalog) else {
            Issue.record("Expected date setup after Shinkansen input")
            return
        }
        #expect(question.id == .legDate)
        #expect(GuidanceProgressEvaluator.isReadyForNow(trip: updated, catalog: catalog) == false)
        #expect(updated.tasks.isEmpty)
    }

    @Test func skipLeavesPausedGuidanceInsteadOfReady() throws {
        let catalog = try EngineTestSupport.catalog()
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        trip = try brain.process(
            trip: trip,
            command: .applyMutation(.setTransportMode(trip.legs[0].id, .shinkansen))
        ).updatedTrip
        let moment = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
        trip = try brain.process(
            trip: trip,
            command: .answerQuestion(.legDate, .scheduledMoment(moment))
        ).updatedTrip
        trip = try brain.process(
            trip: trip,
            command: .answerQuestion(.ticketStatus, .choice("unsure"))
        ).updatedTrip
        trip = try brain.process(
            trip: trip,
            command: .answerQuestion(.luggagePresence, .choice("skip"))
        ).updatedTrip
        guard case .paused = GuidanceProgressEvaluator.evaluate(trip: trip, catalog: catalog) else {
            Issue.record("Expected paused guidance after skipped setup answers")
            return
        }
        #expect(GuidanceProgressEvaluator.isReadyForNow(trip: trip, catalog: catalog) == false)
    }
}
