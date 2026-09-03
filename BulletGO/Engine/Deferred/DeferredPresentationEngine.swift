import Foundation

nonisolated enum DeferredPresentationEngine {
    static func apply(
        to trip: Trip,
        activeDecisionPoints: Set<DecisionPointID>,
        at now: Date
    ) throws -> Trip {
        guard activeDecisionPoints.contains(.seatSelection) else {
            return trip
        }
        let focus = try trip.focusLeg()
        guard case .deferred(until: .seatSelection) = focus.seatPreference.presentationTiming else {
            return trip
        }

        var updated = trip
        try updated.updateLeg(id: focus.id) { leg in
            leg.seatPreference = try leg.seatPreference.updating(
                value: leg.seatPreference.value,
                status: leg.seatPreference.status,
                source: leg.seatPreference.source,
                confidence: leg.seatPreference.confidence,
                presentationTiming: .immediate,
                at: now
            )
        }
        updated.changeEvents.append(
            TripChangeEvent(
                id: ChangeEventID(),
                kind: .other,
                target: .leg(focus.id),
                changedPaths: [.leg(focus.id, .seatPreference)],
                affectedFrom: nil,
                potentialScope: .specificLegs([focus.id]),
                impactLevel: .low,
                createdAt: now
            )
        )
        updated.updatedAt = now
        try updated.validate()
        return updated
    }
}
