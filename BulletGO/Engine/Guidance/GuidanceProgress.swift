import Foundation

nonisolated enum GuidanceProgress: Equatable, Sendable {
    case notStarted
    case needsSetup(QuestionSpec)
    case paused(QuestionSpec)
    case ready
}

nonisolated enum GuidanceProgressEvaluator {
    static func evaluate(
        trip: Trip,
        catalog: QuestionCatalog,
        activeDecisionPoints: Set<DecisionPointID>? = nil
    ) -> GuidanceProgress {
        let points = activeDecisionPoints ?? DecisionPointResolver.activePoints(in: trip)
        let applicable = QuestionEngine.applicableQuestions(
            in: trip,
            catalog: catalog,
            activeDecisionPoints: points,
            role: .setup
        )
        guard let leg = try? trip.focusLeg() else {
            return .notStarted
        }

        let incomplete = applicable.first { question in
            !QuestionEngine.isConfirmed(question.target, trip: trip, leg: leg)
        }
        let nextPass = QuestionEngine.nextSetupQuestion(
            in: trip,
            catalog: catalog,
            activeDecisionPoints: points
        )
        let started = applicable.contains { question in
            hasStarted(question.target, trip: trip, leg: leg)
        }

        if incomplete == nil {
            return .ready
        }
        if !started {
            return .notStarted
        }
        if let nextPass {
            return .needsSetup(nextPass)
        }
        return .paused(incomplete!)
    }

    static func isReadyForNow(
        trip: Trip,
        catalog: QuestionCatalog
    ) -> Bool {
        if case .ready = evaluate(trip: trip, catalog: catalog) {
            return true
        }
        return false
    }

    private static func hasStarted(
        _ target: QuestionTarget,
        trip: Trip,
        leg: Leg
    ) -> Bool {
        switch target {
        case .legScheduledAt:
            return hasProgress(leg.scheduledAt)
        case .legTransportMode:
            return hasProgress(leg.transportMode)
        case .legReservationStatus:
            return hasProgress(leg.reservation.status)
        case .legReservationService:
            return hasProgress(leg.reservation.service)
        case .legBaggagePresence:
            return hasProgress(leg.baggagePresence)
        case .bagDimensions:
            return trip.baggageInventory.contains { bag in
                leg.bagIDs.contains(bag.id) && hasProgress(bag.dimensions)
            }
        }
    }

    private static func hasProgress<Value: Hashable & Codable & Sendable>(_ slot: Slot<Value>) -> Bool {
        switch slot.status {
        case .confirmed, .skipped, .negative, .notApplicable, .inferred:
            true
        case .unknown:
            false
        }
    }
}
