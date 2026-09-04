import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripBrainTests {
    @Test func answeringTransportAdvancesPhaseAndAsksTicketStatus() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try DomainTestSupport.sampleTrip()
        let date = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
        trip = try brain.process(
            trip: trip,
            command: .applyMutation(.setLegScheduledAt(trip.legs[0].id, date))
        ).updatedTrip
        let result = try brain.process(
            trip: trip,
            command: .answerQuestion(.transport, .choice("shinkansen"))
        )
        #expect(result.updatedTrip.legs[0].transportMode.value == .shinkansen)
        #expect(result.updatedTrip.legs[0].phase == .booking)
        #expect(result.phaseProposal?.autoApplied == true)
        #expect(result.nextQuestion?.id == .ticketStatus)
    }

    @Test func luggageThenDimensionsThenOversizedTaskAppear() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            service: .smartEX,
            baggagePresence: nil,
            bags: []
        )
        trip = try brain.process(trip: trip, command: .answerQuestion(.luggagePresence, .choice("yes"))).updatedTrip
        #expect(trip.baggageInventory.count == 1)
        #expect(trip.legs[0].policyEvaluations.contains { $0.status == .needsMoreInformation })
        let next = try brain.process(trip: trip, command: .reevaluate)
        #expect(next.nextQuestion?.id == .baggageDimensions)

        let dimensions = try PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31)
        let after = try brain.process(
            trip: next.updatedTrip,
            command: .answerQuestion(.baggageDimensions, .dimensions(dimensions))
        )
        #expect(after.updatedTrip.tasks.contains { $0.contentKey == ActionPurpose.reserveOversizedSeat })
        #expect(after.actions.contains { $0.purposeKey == ActionPurpose.reserveOversizedSeat })
        #expect(after.nextQuestion == nil)
    }

    @Test func unknownQuestionDoesNotMutateTrip() throws {
        let brain = try EngineTestSupport.brain()
        let trip = try DomainTestSupport.sampleTrip()
        #expect(throws: EngineError.unknownQuestion("q_missing")) {
            try brain.process(trip: trip, command: .answerQuestion(QuestionID(rawValue: "q_missing"), .skip))
        }
    }

    @Test func userInputReturnsSummaryWhilePhaseEventDoesNot() throws {
        let brain = try EngineTestSupport.brain()
        var trip = try PolicyScenarioSupport.trip(
            reservation: .booked,
            reservationSource: .userConfirmed,
            baggagePresence: .no,
            bags: []
        )
        let mutationResult = try brain.process(
            trip: trip,
            command: .applyMutation(.setSeatPreference(trip.legs[0].id, .mountFujiView))
        )
        #expect(mutationResult.understandingSummary != nil)
        trip = mutationResult.updatedTrip
        let phase = try brain.process(trip: trip, command: .applyPhaseEvent(.startPreparing))
        #expect(phase.understandingSummary == nil)
        #expect(phase.updatedTrip.legs[0].seatPreference.presentationTiming == .deferred(until: .seatSelection))
    }

    @Test func reevaluateSyncsTripPhaseFromDatesWithoutChangingLegPhase() throws {
        let today = try LocalDate(year: 2026, month: 10, day: 4)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TripPhaseResolver.calendarTimeZone
        let now = try #require(
            calendar.date(from: DateComponents(year: today.year, month: today.month, day: today.day, hour: 12))
        )
        let brain = TripBrain(
            catalog: try EngineTestSupport.catalog(),
            pack: try EngineTestSupport.pack(),
            clock: .fixed(now)
        )
        let trip = try DomainTestSupport.sampleTrip()
        #expect(trip.currentContext.tripPhase == .planning)
        let result = try brain.process(trip: trip, command: .reevaluate)
        #expect(result.updatedTrip.currentContext.tripPhase == .inTrip)
        #expect(result.updatedTrip.legs.map(\.phase) == trip.legs.map(\.phase))
    }
}
