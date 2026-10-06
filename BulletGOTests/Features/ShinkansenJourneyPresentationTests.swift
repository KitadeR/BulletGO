import Foundation
import Testing
@testable import BulletGO

struct ShinkansenJourneyPresentationTests {
    private let pack = try! PackLoader.loadProduction(from: .main)

    @Test func bookingStatusAndBaggageDetermineTheNextCard() throws {
        let unknown = try PolicyScenarioSupport.trip(reservation: nil, baggagePresence: nil)
        #expect(snapshot(unknown).focus == .conditions)
        #expect(snapshot(unknown).booking == nil)

        let noBag = try PolicyScenarioSupport.trip(reservation: .notBooked, baggagePresence: .no)
        #expect(snapshot(noBag).baggage == .none)
        #expect(snapshot(noBag).focus == .reservation)

        let unmeasured = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, nil)]
        )
        #expect(snapshot(unmeasured).baggage == .needsMeasurement)
        #expect(snapshot(unmeasured).focus == .conditions)

        let booked = try PolicyScenarioSupport.trip(reservation: .booked, baggagePresence: .no)
        #expect(snapshot(booked).focus == .boarding)
    }

    @Test func baggageThresholdsAreExact() throws {
        let cases: [(Double, ShinkansenJourneyPresentation.Baggage)] = [
            (160, .withinLimit), (161, .oversizedSeat), (251, .notAllowed)
        ]
        for (total, expected) in cases {
            let trip = try PolicyScenarioSupport.trip(
                reservation: .notBooked,
                baggagePresence: .yes,
                bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: total - 80, widthCM: 40, heightCM: 40))]
            )
            #expect(snapshot(trip).baggage == expected)
        }
    }

    @Test func changingReservationOrDateRemovesRelatedStatements() throws {
        var trip = try PolicyScenarioSupport.trip(reservation: .booked, baggagePresence: .no)
        let id = trip.legs[0].id
        trip.legs[0].reservation.statedBoarding = .qrTicket
        trip.legs[0].reservation.details.oversizedSeatReserved = true
        let changed = try TripMutationApplier.apply(.setReservationStatus(id, .notBooked, .confirmed), to: trip, at: PolicyScenarioSupport.now)
        #expect(changed.legs[0].reservation.statedBoarding == nil)
        #expect(changed.legs[0].reservation.details.oversizedSeatReserved == nil)

        let nextDate = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 2))
        let rescheduled = try TripMutationApplier.apply(.setLegScheduledAt(id, nextDate), to: trip, at: PolicyScenarioSupport.now)
        #expect(rescheduled.legs[0].reservation.status.status == .unknown)
        #expect(rescheduled.legs[0].reservation.statedBoarding == nil)
        #expect(rescheduled.legs[0].reservation.details.oversizedSeatReserved == nil)
    }

    @Test func boardingMeansRemainIndividualStatements() throws {
        let original = try PolicyScenarioSupport.trip(reservation: .booked, baggagePresence: .no)
        let id = original.legs[0].id
        for means in StatedBoardingMeans.allCases {
            let trip = try TripMutationApplier.apply(.setStatedBoarding(id, means), to: original, at: PolicyScenarioSupport.now)
            #expect(snapshot(trip).boarding == means)
            #expect(snapshot(trip).focus == .travelDay)
        }
        #expect(snapshot(original).boarding == nil)
    }

    @Test func methodActionWaitsForBaggageDimensions() throws {
        let unmeasured = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, nil)]
        )
        #expect(!ActionResolver.resolve(trip: unmeasured, pack: pack).contains { $0.purposeKey == ActionPurpose.selectBookingMethod })
        let measured = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: 81, widthCM: 40, heightCM: 40))]
        )
        #expect(ActionResolver.resolve(trip: measured, pack: pack).contains { $0.purposeKey == ActionPurpose.selectBookingMethod })
        let tooLarge = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: 171, widthCM: 40, heightCM: 40))]
        )
        #expect(!ActionResolver.resolve(trip: tooLarge, pack: pack).contains { $0.purposeKey == ActionPurpose.selectBookingMethod })
    }

    @Test func oversizedSeatStatementClosesOnlyItsOwnReminder() throws {
        var trip = try PolicyScenarioSupport.trip(
            reservation: .booked,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: 81, widthCM: 40, heightCM: 40))]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: PolicyScenarioSupport.now)
        #expect(ActionResolver.resolve(trip: trip, pack: pack).contains { $0.purposeKey == ActionPurpose.verifyReservationMeetsBaggage })
        trip.legs[0].reservation.details.oversizedSeatReserved = true
        #expect(!ActionResolver.resolve(trip: trip, pack: pack).contains { $0.purposeKey == ActionPurpose.verifyReservationMeetsBaggage })
        #expect(trip.legs[0].reservation.status.value == .booked)
    }

    private func snapshot(_ trip: Trip) -> ShinkansenJourneyPresentation {
        ShinkansenJourneyPresentation.make(trip: trip, leg: trip.legs[0], pack: pack)
    }
}
