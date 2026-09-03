import Foundation
import Testing
@testable import BulletGO

@MainActor
struct PhaseEngineTests {
    @Test func confirmsTransportAutoMovesPlanningToBooking() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let afterTransport = try TripMutationApplier.apply(
            .setTransportMode(trip.legs[0].id, .shinkansen),
            to: trip,
            at: EngineTestSupport.now
        )
        let result = try PhaseEngine.applyAutomaticTransition(to: afterTransport)
        #expect(result.0.legs[0].phase == .booking)
        #expect(result.1?.autoApplied == true)
        #expect(result.1?.to == .booking)
    }

    @Test func bookedUserConfirmedOnlyProposesPreparing() throws {
        var trip = try PolicyScenarioSupport.trip(
            reservation: .booked,
            reservationSource: .userConfirmed,
            bags: []
        )
        try trip.updateLeg(id: trip.legs[0].id) { $0.phase = .booking }
        let proposal = try PhaseEngine.applyAutomaticTransition(to: trip)
        #expect(proposal.0.legs[0].phase == .booking)
        #expect(proposal.1?.autoApplied == false)
        #expect(proposal.1?.to == .preparing)
    }

    @Test func bookedUserStatedDoesNotProposePreparing() throws {
        var trip = try PolicyScenarioSupport.trip(reservation: .booked, bags: [])
        try trip.updateLeg(id: trip.legs[0].id) { $0.phase = .booking }
        let proposal = try PhaseEngine.applyAutomaticTransition(to: trip)
        #expect(proposal.1 == nil)
    }

    @Test func manualEventsFollowTypedContract() throws {
        var trip = try PolicyScenarioSupport.trip(bags: [])
        try trip.updateLeg(id: trip.legs[0].id) { $0.phase = .booking }
        trip = try PhaseEngine.apply(.startPreparing, to: trip)
        #expect(trip.legs[0].phase == .preparing)
        #expect(throws: EngineError.invalidPhaseTransition) {
            try PhaseEngine.apply(.complete, to: trip)
        }
    }
}
