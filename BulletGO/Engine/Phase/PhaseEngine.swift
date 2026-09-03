import Foundation

nonisolated struct PhaseProposal: Hashable, Sendable {
    var from: LegPhase
    var to: LegPhase
    var autoApplied: Bool
}

nonisolated enum PhaseEngine {
    static func applyAutomaticTransition(to trip: Trip) throws -> (Trip, PhaseProposal?) {
        guard let leg = try? trip.focusLeg() else {
            return (trip, nil)
        }
        if leg.phase == .planning, leg.transportMode.status == .confirmed {
            var updated = trip
            try updated.updateLeg(id: leg.id) { focus in
                focus.phase = .booking
            }
            return (
                updated,
                PhaseProposal(from: .planning, to: .booking, autoApplied: true)
            )
        }
        if leg.phase == .booking,
           leg.reservation.status.status == .confirmed,
           leg.reservation.status.value == .booked,
           leg.reservation.status.source == .userConfirmed
        {
            return (
                trip,
                PhaseProposal(from: .booking, to: .preparing, autoApplied: false)
            )
        }
        return (trip, nil)
    }

    static func apply(_ event: PhaseManualEvent, to trip: Trip) throws -> Trip {
        let leg = try trip.focusLeg()
        let destination = destinationPhase(event)
        guard allowedTransitions[leg.phase]?.contains(destination) == true else {
            throw EngineError.invalidPhaseTransition
        }
        var updated = trip
        try updated.updateLeg(id: leg.id) { focus in
            focus.phase = destination
        }
        return updated
    }

    private static func destinationPhase(_ event: PhaseManualEvent) -> LegPhase {
        switch event {
        case .startPreparing: .preparing
        case .startGoingToDeparture: .goingToDeparture
        case .arriveAtDeparture: .atDeparture
        case .startBoarding: .boarding
        case .startTransit: .inTransit
        case .arrive: .arriving
        case .complete: .completed
        }
    }

    private static let allowedTransitions: [LegPhase: Set<LegPhase>] = [
        .planning: [.booking],
        .booking: [.preparing],
        .preparing: [.goingToDeparture],
        .goingToDeparture: [.atDeparture],
        .atDeparture: [.boarding],
        .boarding: [.inTransit],
        .inTransit: [.arriving],
        .arriving: [.completed],
    ]
}
