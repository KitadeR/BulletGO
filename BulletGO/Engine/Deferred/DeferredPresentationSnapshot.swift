import Foundation

nonisolated struct DeferredPresentationItem: Hashable, Sendable {
    var contentKey: String
    var scope: DomainScope
    var field: DomainPath
    var decisionPoint: DecisionPointID
    var presentationTiming: SlotPresentationTiming
}

nonisolated struct DeferredPresentationSnapshot: Hashable, Sendable {
    var remembered: [DeferredPresentationItem]
    var next: [DeferredPresentationItem]

    static let empty = DeferredPresentationSnapshot(remembered: [], next: [])
}

nonisolated enum DeferredPresentationProjector {
    static let seatPreferenceContentKey = "leg.seatPreference"

    static func snapshot(for trip: Trip) -> DeferredPresentationSnapshot {
        guard let focusID = trip.focusLegID else {
            return .empty
        }
        return snapshot(for: trip, legID: focusID)
    }

    static func snapshot(for trip: Trip, legID: LegID) -> DeferredPresentationSnapshot {
        guard let leg = trip.legs.first(where: { $0.id == legID }) else {
            return .empty
        }
        guard let item = seatPreferenceItem(for: leg) else {
            return .empty
        }
        var remembered: [DeferredPresentationItem] = []
        var next: [DeferredPresentationItem] = []
        remembered.append(item)
        if case .deferred = item.presentationTiming {
            next.append(item)
        }
        return DeferredPresentationSnapshot(remembered: remembered, next: next)
    }

    private static func seatPreferenceItem(for leg: Leg) -> DeferredPresentationItem? {
        guard leg.seatPreference.hasDeferredPresentationHistory else {
            return nil
        }
        let decisionPoint: DecisionPointID
        if case .deferred(let until) = leg.seatPreference.presentationTiming {
            decisionPoint = until
        } else {
            decisionPoint = deferredDecisionPoint(in: leg.seatPreference.revisions) ?? .seatSelection
        }
        return DeferredPresentationItem(
            contentKey: seatPreferenceContentKey,
            scope: .leg(leg.id),
            field: .leg(leg.id, .seatPreference),
            decisionPoint: decisionPoint,
            presentationTiming: leg.seatPreference.presentationTiming
        )
    }

    private static func deferredDecisionPoint(in revisions: [SlotRevision<SeatPreference>]) -> DecisionPointID? {
        for revision in revisions.reversed() {
            if case .deferred(let until) = revision.presentationTiming {
                return until
            }
        }
        return nil
    }
}
