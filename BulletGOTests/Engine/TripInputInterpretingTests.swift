import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripInputInterpretingTests {
    @Test func englishShinkansenAndFujiBecomeTypedMutations() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let interpretation = LocalDeterministicTripInputInterpreter().interpret(
            "I want to take the Shinkansen! I'd like a seat with a view of Mt. Fuji.",
            trip: trip,
            legID: trip.legs[0].id
        )
        #expect(interpretation.fallbackToStructuredQuestions == false)
        #expect(interpretation.recognizedIntent == .shinkansenWithFujiView)
        #expect(interpretation.mutations == [
            .setTransportMode(trip.legs[0].id, .shinkansen),
            .setSeatPreference(trip.legs[0].id, .mountFujiView),
        ])
    }

    @Test func unknownCopyConfirmsNothing() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let interpretation = LocalDeterministicTripInputInterpreter().interpret(
            "Maybe a bus? Not sure yet.",
            trip: trip,
            legID: trip.legs[0].id
        )
        #expect(interpretation.mutations.isEmpty)
        #expect(interpretation.fallbackToStructuredQuestions)
        #expect(interpretation.recognizedIntent == nil)
    }

    @Test func japaneseShinkansenAndFujiBecomeTypedMutations() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let interpretation = LocalDeterministicTripInputInterpreter().interpret(
            "新幹線で行きたい。富士山が見える席がいい。",
            trip: trip,
            legID: trip.legs[0].id
        )
        #expect(interpretation.fallbackToStructuredQuestions == false)
        #expect(interpretation.recognizedIntent == .shinkansenWithFujiView)
        #expect(interpretation.mutations == [
            .setTransportMode(trip.legs[0].id, .shinkansen),
            .setSeatPreference(trip.legs[0].id, .mountFujiView),
        ])
    }
}
