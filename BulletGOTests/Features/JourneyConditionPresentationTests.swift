import Foundation
import Testing
@testable import BulletGO

struct JourneyConditionPresentationTests {
    @Test func emptyLegConfirmsTheRouteAndAsksDate() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.facts.map(\.id) == [.route])
        #expect(snapshot.current?.spec.id == .legDate)
        #expect(snapshot.luggageGuide == nil)
        #expect(snapshot.isBookedStop == false)
        #expect(snapshot.chapters.map(\.id) == JourneyChapterID.allCases)
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .movement)
        #expect(snapshot.sheetItem?.title.key == "Travel date")
    }

    @Test func confirmedJourneyAsksBookingNext() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: nil,
            baggagePresence: nil
        )
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.facts.map(\.id) == [.route, .date, .transport])
        #expect(snapshot.current?.spec.id == .ticketStatus)
    }

    @Test func bookedStopsBeforeLuggage() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: .booked,
            baggagePresence: nil
        )
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.isBookedStop == true)
        #expect(snapshot.current == nil)
        #expect(snapshot.facts.contains(where: { $0.id == .booking }) == true)
        #expect(snapshot.facts.contains(where: { $0.id == .luggage }) == false)
        #expect(snapshot.luggageGuide == nil)
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .boarding)
        #expect(snapshot.chapters.first { $0.id == .boarding }?.status == .localized(LocalizedStringResource(
            "After you book",
            comment: "Chapter status for boarding preparation before a ticket path exists."
        )))
        #expect(snapshot.sheetItem == nil)
    }

    @Test func notBookedShinkansenAsksLuggage() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: .notBooked,
            baggagePresence: nil
        )
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.current?.spec.id == .luggagePresence)
        #expect(snapshot.isBookedStop == false)
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .conditions)
    }

    @Test func airplaneOmitsLuggage() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .airplane,
            reservation: .notBooked,
            baggagePresence: nil
        )
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.current == nil)
        #expect(snapshot.facts.contains(where: { $0.id == .luggage }) == false)
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .reservation)
        #expect(snapshot.sheetItem?.title.key == "Choose how to book")
    }

    @Test func skippedBookingDoesNotAskLuggage() throws {
        var trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: nil,
            baggagePresence: nil
        )
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.reservation.status = try Slot.skipped(updatedAt: DomainTestSupport.timestamp)
        }
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.current == nil)
        #expect(snapshot.facts.contains(where: { $0.id == .booking }) == true)
        #expect(snapshot.facts.contains(where: { $0.id == .luggage }) == false)
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .conditions)
        #expect(snapshot.sheetItem == nil)
    }

    @Test func luggageYesOpensTheMeasurementGuide() throws {
        var trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: .notBooked,
            baggagePresence: .yes
        )
        let task = TripTask(
            id: TaskID(),
            contentKey: ActionPurpose.captureDimensions,
            type: .check,
            state: .notStarted,
            importance: .required,
            relevantPhases: [.planning, .booking],
            deadline: nil,
            dependencies: [],
            evidence: .none,
            scope: .leg(trip.legs[0].id),
            relatedActionID: nil,
            relatedPolicyID: .jrShinkansenOversizedBaggage,
            relatedGuideID: .shinkansenBaggageMeasurement,
            completionCondition: .userConfirmsDone
        )
        trip.tasks = [task]
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.current == nil)
        #expect(snapshot.facts.contains(where: { $0.id == .luggage }) == true)
        #expect(snapshot.luggageGuide?.kind == .task(task.id))
        #expect(snapshot.luggageGuide?.destination == .baggageCheck(trip.id, trip.legs[0].id, task.id))
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .conditions)
        #expect(snapshot.sheetItem?.title.key == "Confirm luggage size")
    }

    @Test func bookedDoesNotOpenLuggageGuide() throws {
        var trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: .booked,
            baggagePresence: .yes
        )
        trip.tasks = [
            TripTask(
                id: TaskID(),
                contentKey: ActionPurpose.captureDimensions,
                type: .check,
                state: .notStarted,
                importance: .required,
                relevantPhases: [.planning, .booking],
                deadline: nil,
                dependencies: [],
                evidence: .none,
                scope: .leg(trip.legs[0].id),
                relatedActionID: nil,
                relatedPolicyID: .jrShinkansenOversizedBaggage,
                relatedGuideID: .shinkansenBaggageMeasurement,
                completionCondition: .userConfirmsDone
            )
        ]
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.isBookedStop == true)
        #expect(snapshot.luggageGuide == nil)
    }

    @Test func reopenedDateBecomesTheOpenQuestion() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: .notBooked,
            baggagePresence: nil
        )
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog(),
            reopenedQuestionID: .legDate
        )
        #expect(snapshot.current?.spec.id == .legDate)
        #expect(snapshot.facts.contains(where: { $0.id == .date }) == false)
        #expect(snapshot.facts.contains(where: { $0.id == .transport }) == true)
    }
}
