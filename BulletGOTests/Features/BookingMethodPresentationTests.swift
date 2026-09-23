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
}
