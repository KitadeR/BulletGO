import Foundation
import Testing
@testable import BulletGO

struct LegCockpitPresentationTests {
    @Test func bookedReservationIsNotReady() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.legs[0].reservation.status = try Slot.confirmed(
            value: .booked,
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.readinessChecks = []
        let snapshot = LegCockpitComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.reservationStatus == .localized(TripContentResolver.reservationStatusText(trip.legs[0].reservation)))
        #expect(snapshot.bookingReadiness == .unverified)
        #expect(snapshot.bookingReadiness != .ready)
        #expect(snapshot.luggageReadiness != .ready)
    }

    @Test func whatsNextUsesDisplayPipelineHeadForThisLeg() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let first = makeTask(ActionPurpose.captureDimensions, importance: .required, scope: focus)
        let second = makeTask(ActionPurpose.selectBookingMethod, importance: .important, scope: focus)
        trip.tasks = [first, second]
        trip.legs[0].phase = .booking
        let catalog = try EngineTestSupport.catalog()
        trip = try markReady(trip)
        let snapshot = LegCockpitComposer.snapshot(trip: trip, leg: trip.legs[0], catalog: catalog)
        #expect(snapshot.whatsNext?.kind == .task(first.id))
        #expect(snapshot.needsSetup == false)
    }

    @Test func emptyLegStartsWithDateAsCurrent() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.mode == .setup)
        #expect(snapshot.setup?.currentQuestionID == .legDate)
        #expect(snapshot.setup?.steps.first?.kind == .current)
        #expect(snapshot.setup?.steps.first?.question.id == .legDate)
        #expect(snapshot.cockpit == nil)
    }

    @Test func confirmedDateMakesTransportCurrent() throws {
        var trip = try DomainTestSupport.sampleTrip()
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.scheduledAt = try Slot.confirmed(
                value: try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
                source: .userStated,
                updatedAt: DomainTestSupport.timestamp
            )
        }
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.setup?.currentQuestionID == .transport)
        #expect(snapshot.setup?.steps.first { $0.question.id == .legDate }?.kind == .completed)
    }

    @Test func shinkansenAddsLuggageStep() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: nil,
            baggagePresence: nil
        )
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.setup?.steps.contains { $0.question.id == .luggagePresence } == true)
        #expect(snapshot.setup?.currentQuestionID == .ticketStatus)
    }

    @Test func airplaneOmitsShinkansenLuggageStep() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .airplane,
            reservation: nil,
            baggagePresence: nil
        )
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.setup?.steps.contains { $0.question.id == .luggagePresence } == false)
        #expect(snapshot.setup?.steps.contains { $0.question.id == .ticketStatus } == true)
    }

    @Test func bookingStepUsesBookingTitleAndGenericPrompt() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        let booking = snapshot.setup?.steps.first { $0.question.id == .ticketStatus }
        #expect(booking?.title.key == "Booking")
        #expect(booking?.prompt.key == "Have you booked this journey yet?")
    }

    @Test func shinkansenBookingPromptNamesTheService() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: nil,
            baggagePresence: nil
        )
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        let booking = snapshot.setup?.steps.first { $0.question.id == .ticketStatus }
        #expect(booking?.prompt.key == "Have you already booked the Shinkansen?")
    }

    @Test func skippedBookingAdvancesToLuggageNotTheSameQuestion() throws {
        var trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: nil,
            baggagePresence: nil
        )
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.reservation.status = try Slot.skipped(updatedAt: DomainTestSupport.timestamp)
        }
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.mode == .setup)
        #expect(snapshot.setup?.currentQuestionID == .luggagePresence)
        let booking = snapshot.setup?.steps.first { $0.question.id == .ticketStatus }
        #expect(booking?.kind == .deferred)
        #expect(booking?.valueText == TripContentResolver.deferredSetupValue())
        #expect(snapshot.setup?.steps.contains { $0.kind == .current && $0.question.id == .ticketStatus } == false)
    }

    @Test func pausedSetupHasNoCurrentAndDoesNotBecomeCockpit() throws {
        var trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: nil,
            baggagePresence: nil
        )
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.reservation.status = try Slot.skipped(updatedAt: DomainTestSupport.timestamp)
            leg.baggagePresence = try Slot.skipped(updatedAt: DomainTestSupport.timestamp)
        }
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.mode == .setup)
        #expect(snapshot.setup?.isPaused == true)
        #expect(snapshot.setup?.currentQuestionID == nil)
        #expect(snapshot.setup?.steps.contains { $0.kind == .current } == false)
        #expect(snapshot.setup?.steps.filter { $0.kind == .deferred }.count == 2)
        #expect(snapshot.cockpit == nil)
    }

    @Test func confirmedSetupIsCockpit() throws {
        let trip = try markReady(try DomainTestSupport.sampleTrip())
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.mode == .cockpit)
        #expect(snapshot.setup == nil)
        #expect(snapshot.cockpit != nil)
    }

    @Test func composerUsesTemporaryFocusWithoutChangingTheTrip() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let originalFocus = trip.focusLegID
        trip.currentContext.focus = .leg(trip.legs[1].id)
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.mode == .setup)
        #expect(snapshot.setup?.currentQuestionID == .legDate)
        #expect(originalFocus == trip.legs[0].id)
        #expect(trip.focusLegID == trip.legs[1].id)
    }
}

private func makeTask(
    _ contentKey: String,
    importance: TaskImportance,
    scope: LegID
) -> TripTask {
    TripTask(
        id: TaskID(),
        contentKey: contentKey,
        type: .check,
        state: .notStarted,
        importance: importance,
        relevantPhases: [.planning, .booking],
        deadline: nil,
        dependencies: [],
        evidence: .none,
        scope: .leg(scope),
        relatedActionID: nil,
        relatedPolicyID: .jrShinkansenOversizedBaggage,
        relatedGuideID: nil,
        completionCondition: .userConfirmsDone
    )
}

private func markReady(_ trip: Trip) throws -> Trip {
    var working = trip
    let now = DomainTestSupport.timestamp
    working.legs[0].scheduledAt = try Slot.confirmed(
        value: EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
        source: .userStated,
        updatedAt: now
    )
    working.legs[0].transportMode = try Slot.confirmed(value: .shinkansen, source: .userStated, updatedAt: now)
    working.legs[0].reservation.status = try Slot.confirmed(value: .notBooked, source: .userStated, updatedAt: now)
    working.legs[0].baggagePresence = try Slot.confirmed(value: .yes, source: .userStated, updatedAt: now)
    working.legs[0].phase = .booking
    try working.validate()
    return working
}
