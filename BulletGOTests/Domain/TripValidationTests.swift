import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripValidationTests {
    @Test func sampleTripIsValid() throws {
        let trip = try DomainTestSupport.sampleTrip()
        try trip.validate()
        #expect(trip.legs.count == 3)
        #expect(trip.activities.count == 3)
        #expect(trip.timeline.count == 6)
        #expect(trip.currentContext.focus != .none)
    }

    @Test func duplicateLegIDsFailValidation() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.legs[1] = Leg(
            id: trip.legs[0].id,
            origin: trip.legs[1].origin,
            destination: trip.legs[1].destination,
            scheduledAt: trip.legs[1].scheduledAt,
            transportMode: trip.legs[1].transportMode,
            partyCount: trip.legs[1].partyCount,
            baggagePresence: trip.legs[1].baggagePresence,
            bagIDs: trip.legs[1].bagIDs,
            reservation: trip.legs[1].reservation,
            phase: trip.legs[1].phase,
            policyEvaluations: trip.legs[1].policyEvaluations,
            activeProcedureIDs: trip.legs[1].activeProcedureIDs
        )
        #expect(throws: TripValidationError.duplicateLegIDs) {
            try trip.validate()
        }
    }

    @Test func unresolvedTimelineItemFailsValidation() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.timeline.append(.leg(LegID()))
        #expect(throws: TripValidationError.unresolvedTimelineItem(trip.timeline.last!)) {
            try trip.validate()
        }
    }

    @Test func bagReferenceMustExistInInventory() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let missing = BagID()
        trip.legs[0].bagIDs = [missing]
        #expect(throws: TripValidationError.bagNotInInventory(missing)) {
            try trip.validate()
        }
    }

    @Test func currentFocusMustResolve() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.currentContext.focus = .activity(ActivityID())
        #expect(throws: TripValidationError.unresolvedCurrentFocus) {
            try trip.validate()
        }
    }

    @Test func currentContextTripMustMatch() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.currentContext.tripID = TripID()
        #expect(throws: TripValidationError.currentContextTripMismatch) {
            try trip.validate()
        }
    }

    @Test func invertedDatesFailValidation() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let later = try LocalDate(year: 2026, month: 11, day: 1)
        let earlier = try LocalDate(year: 2026, month: 10, day: 1)
        trip.startDate = try Slot.confirmed(value: later, source: .userStated, updatedAt: DomainTestSupport.timestamp)
        trip.endDate = try Slot.confirmed(value: earlier, source: .userStated, updatedAt: DomainTestSupport.timestamp)
        #expect(throws: TripValidationError.invertedTravelDates) {
            try trip.validate()
        }
    }

    @Test func validBagReferencePasses() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let bag = Bag(
            id: BagID(),
            kind: try Slot.inferred(value: .suitcase, updatedAt: DomainTestSupport.timestamp),
            userDescription: try Slot.unknown(updatedAt: DomainTestSupport.timestamp),
            perceivedSize: try Slot.unknown(updatedAt: DomainTestSupport.timestamp),
            dimensions: try Slot.unknown(updatedAt: DomainTestSupport.timestamp),
            weightKilograms: try Slot.unknown(updatedAt: DomainTestSupport.timestamp),
            createdAt: DomainTestSupport.timestamp
        )
        trip.baggageInventory = [bag]
        trip.legs[0].bagIDs = [bag.id]
        try trip.validate()
    }
}
