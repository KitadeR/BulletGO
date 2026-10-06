import Foundation
import Testing
@testable import BulletGO

struct BookingMethodPresentationTests {
    @Test func listShowsFiveMethodsAndOnlySmartEXContinues() {
        let methods = BookingMethodID.allCases
        #expect(methods.map(\.rawValue) == ["smartEX", "klook", "jrWestOnline", "station", "japanRailPass"])
        #expect(methods.filter(\.advances) == [.smartEX])
    }

    @Test func smartEXOpensItsOwnScreenAndOthersOpenComingSoon() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let legID = trip.legs[0].id
        #expect(BookingMethodID.smartEX.route(tripID: trip.id, legID: legID) == .bookingMethodSmartEX(trip.id, legID))
        for method in BookingMethodID.allCases where method != .smartEX {
            #expect(method.route(tripID: trip.id, legID: legID) == .bookingMethodComingSoon(trip.id, legID, method))
        }
    }

    @Test func choosingAMethodDoesNotChangeTheReservation() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .shinkansen,
            reservation: .notBooked,
            baggagePresence: .no
        )
        let before = trip.legs[0].reservation
        _ = BookingMethodID.smartEX.route(tripID: trip.id, legID: trip.legs[0].id)
        #expect(trip.legs[0].reservation.status.value == .notBooked)
        #expect(trip.legs[0].reservation.service.status != .confirmed)
        #expect(trip.legs[0].reservation.status.value == before.status.value)
    }

    @Test func oversizedBagAsksForTheSpecialSeatAndDoesNotBook() throws {
        let pack = try PackLoader.loadProduction(from: .main)
        let trip = try PolicyScenarioSupport.trip(
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: 80, widthCM: 40, heightCM: 41))]
        )
        let before = trip.legs[0].reservation.status.value
        let guidance = SmartEXGuidance.make(trip: trip, leg: trip.legs[0], pack: pack)
        #expect(guidance.needsOversizedSeat)
        #expect(guidance.dateText == "2026/10/01")
        #expect(guidance.routeTitle?.contains("→") == true)
        #expect(trip.legs[0].reservation.status.value == before)
        #expect(trip.legs[0].reservation.service.status != .confirmed)
    }

    @Test func ordinaryOrUnknownBagsOmitTheOversizedLine() throws {
        let pack = try PackLoader.loadProduction(from: .main)
        let within = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: 80, widthCM: 40, heightCM: 40))]
        )
        let unknown = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, nil)]
        )
        let none = try PolicyScenarioSupport.trip(baggagePresence: .no)
        #expect(SmartEXGuidance.make(trip: within, leg: within.legs[0], pack: pack).needsOversizedSeat == false)
        #expect(SmartEXGuidance.make(trip: unknown, leg: unknown.legs[0], pack: pack).needsOversizedSeat == false)
        #expect(SmartEXGuidance.make(trip: none, leg: none.legs[0], pack: pack).needsOversizedSeat == false)
        #expect(SmartEXGuidance.officialURL.absoluteString == "https://smart-ex.jp/")
    }

    @Test func recordingTheBookingUpdatesStatusAndDetailsTogether() throws {
        let trip = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            baggagePresence: .no
        )
        let legID = trip.legs[0].id
        #expect(trip.legs[0].reservation.evidenceLevel == .userStated)
        var details = trip.legs[0].reservation.details
        details.confirmationNumber = "ABC123"
        let updated = try TripMutationApplier.apply(
            BookingRecord.mutations(legID: legID, details: details, service: .smartEX),
            to: trip,
            at: PolicyScenarioSupport.now
        )
        #expect(updated.legs[0].reservation.status.value == .booked)
        #expect(updated.legs[0].reservation.details.confirmationNumber == "ABC123")
        #expect(updated.legs[0].reservation.service.value == .smartEX)
        #expect(updated.legs[0].reservation.evidenceLevel == .userStated)
        let snapshot = JourneyConditionComposer.snapshot(
            trip: updated,
            leg: updated.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.chapters.first { $0.isOpen }?.id == .reservation)
        #expect(snapshot.chapters.first { $0.id == .reservation }?.focus?.link == .bookingRecord)
        #expect(updated.legs[0].reservation.statedBoarding == nil)
        #expect(snapshot.chapters.first { $0.id == .boarding }?.notes.map(\.key).contains(
            "Check that the seat includes an oversized-baggage space."
        ) == false)
    }

    @Test func bookedOversizedBagRemindsYouToCheckTheSeat() throws {
        let trip = try recordedRide(PolicyScenarioSupport.trip(
            reservation: .booked,
            service: .smartEX,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, try BaggageDimensions(lengthCM: 80, widthCM: 40, heightCM: 41))]
        ))
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.cockpit?.notes.map(\.key).contains(
            "Check that the seat includes an oversized-baggage space."
        ) == true)
        #expect(snapshot.chapters.allSatisfy { $0.isOpen == false })
    }

    @Test func statingTheCompletionScreenKeepsOneBoardingLine() throws {
        let trip = try recordedRide(PolicyScenarioSupport.trip(
            reservation: .booked,
            service: .smartEX,
            baggagePresence: .no
        ))
        let legID = trip.legs[0].id
        let updated = try TripMutationApplier.apply(
            .setStatedBoarding(legID, .qrTicket),
            to: trip,
            at: PolicyScenarioSupport.now
        )
        #expect(updated.legs[0].reservation.statedBoarding == .qrTicket)
        #expect(updated.legs[0].reservation.status.value == .booked)
        #expect(updated.legs[0].reservation.evidenceLevel == .userStated)
        let snapshot = JourneyConditionComposer.snapshot(
            trip: updated,
            leg: updated.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        let boarding = snapshot.chapters.first { $0.id == .boarding }
        #expect(snapshot.chapters.allSatisfy { $0.isOpen == false })
        #expect(boarding?.boardingChoices.isEmpty == true)
        #expect(boarding?.canRestateBoarding == false)
        #expect(boarding?.status == .localized(StatedBoardingMeans.qrTicket.guidance))
        #expect(snapshot.cockpit?.canRestateBoarding == true)
        #expect(snapshot.cockpit?.boardingChoices.isEmpty == true)
        #expect(snapshot.cockpit?.statedGuidance?.key == StatedBoardingMeans.qrTicket.guidance.key)
        #expect(snapshot.cockpit?.notes.isEmpty == true)
        #expect(snapshot.chapters.first { $0.id == .travelDay }?.status == .localized(LocalizedStringResource(
            "On the day, from the gate through boarding.",
            comment: "Travel-day chapter status. The day stays a plan, without steps."
        )))
        #expect(snapshot.sheetItem == nil)

        let cleared = try TripMutationApplier.apply(
            .setStatedBoarding(legID, nil),
            to: updated,
            at: PolicyScenarioSupport.now
        )
        let again = JourneyConditionComposer.snapshot(
            trip: cleared,
            leg: cleared.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(again.cockpit?.boardingChoices == StatedBoardingMeans.allCases)
        #expect(again.chapters.allSatisfy { $0.isOpen == false })
        #expect(cleared.legs[0].reservation.evidenceLevel == .userStated)
    }

    @Test func recordingTheRideKeepsTheStatementAndOpensBoarding() throws {
        let trip = try PolicyScenarioSupport.trip(
            reservation: .booked,
            service: .smartEX,
            baggagePresence: .no
        )
        #expect(BookingRecord.savedDetails(
            existing: trip.legs[0].reservation.details,
            trainName: " ",
            car: "",
            seat: "",
            confirmationNumber: "2022"
        )?.confirmationNumber == "2022")
        let partial = try #require(BookingRecord.savedDetails(
            existing: trip.legs[0].reservation.details,
            trainName: "Nozomi 74",
            car: "",
            seat: "",
            confirmationNumber: ""
        ))
        #expect(BookingRecord.hasRideDetails(partial) == false)
        let existing = trip.legs[0].reservation.details
        let details = try #require(BookingRecord.savedDetails(
            existing: existing,
            trainName: " Nozomi 74 ",
            car: "14",
            seat: "11A",
            confirmationNumber: "2022"
        ))
        #expect(details.origin == existing.origin)
        let updated = try TripMutationApplier.apply(
            .updateReservationDetails(.leg(trip.legs[0].id), details),
            to: trip,
            at: PolicyScenarioSupport.now
        )
        let reservation = updated.legs[0].reservation
        #expect(reservation.status.value == .booked)
        #expect(reservation.service.value == .smartEX)
        #expect(reservation.evidenceLevel == .userStated)
        #expect(reservation.details.trainName == "Nozomi 74")
        #expect(reservation.details.confirmationNumber == "2022")
        #expect(BookingRecord.hasRideDetails(reservation.details))
        let snapshot = JourneyConditionComposer.snapshot(
            trip: updated,
            leg: updated.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.chapters.allSatisfy { $0.isOpen == false })
        #expect(snapshot.cockpit?.rideSummary == "Nozomi 74 · 14 · 11A")
        #expect(snapshot.cockpit?.bookingLine.key == "Booked · SmartEX")
        #expect(snapshot.cockpit?.boardingChoices == StatedBoardingMeans.allCases)
        #expect(snapshot.cockpit?.canRestateBoarding == false)
        #expect(snapshot.chapters.first { $0.id == .boarding }?.boardingChoices.isEmpty == true)
        #expect(snapshot.chapters.first { $0.id == .boarding }?.status == .localized(LocalizedStringResource(
            "The gate method hasn't been checked yet.",
            comment: "Boarding chapter status after the ride is recorded and the gate method is still unknown."
        )))
        #expect(snapshot.chapters.first { $0.id == .reservation }?.status == .verbatim("Nozomi 74 · 14 · 11A"))
        #expect(snapshot.chapters.first { $0.id == .travelDay }?.isOpen == false)
        #expect(snapshot.sheetItem == nil)
    }
}

private func recordedRide(_ trip: Trip) throws -> Trip {
    let details = try #require(BookingRecord.savedDetails(
        existing: trip.legs[0].reservation.details,
        trainName: "Nozomi 74",
        car: "14",
        seat: "11A",
        confirmationNumber: ""
    ))
    return try TripMutationApplier.apply(
        .updateReservationDetails(.leg(trip.legs[0].id), details),
        to: trip,
        at: PolicyScenarioSupport.now
    )
}
