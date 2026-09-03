import Foundation

nonisolated enum QuestionEngine {
    static func nextQuestion(
        in trip: Trip,
        catalog: QuestionCatalog,
        activeDecisionPoints: Set<DecisionPointID>? = nil,
        role: QuestionRole? = nil
    ) -> QuestionSpec? {
        applicableUnsatisfiedQuestions(
            in: trip,
            catalog: catalog,
            activeDecisionPoints: activeDecisionPoints ?? DecisionPointResolver.activePoints(in: trip),
            role: role
        ).first
    }

    static func nextSetupQuestion(
        in trip: Trip,
        catalog: QuestionCatalog,
        activeDecisionPoints: Set<DecisionPointID>? = nil
    ) -> QuestionSpec? {
        nextQuestion(
            in: trip,
            catalog: catalog,
            activeDecisionPoints: activeDecisionPoints,
            role: .setup
        )
    }

    static func applicableUnsatisfiedQuestions(
        in trip: Trip,
        catalog: QuestionCatalog,
        activeDecisionPoints: Set<DecisionPointID>,
        role: QuestionRole? = nil
    ) -> [QuestionSpec] {
        applicableQuestions(
            in: trip,
            catalog: catalog,
            activeDecisionPoints: activeDecisionPoints,
            role: role
        ).filter { question in
            guard let leg = try? trip.focusLeg() else {
                return false
            }
            return !isSatisfied(question.target, trip: trip, leg: leg)
        }
    }

    static func applicableQuestions(
        in trip: Trip,
        catalog: QuestionCatalog,
        activeDecisionPoints: Set<DecisionPointID>? = nil,
        role: QuestionRole? = nil
    ) -> [QuestionSpec] {
        guard let leg = try? trip.focusLeg() else {
            return []
        }
        let points = activeDecisionPoints ?? DecisionPointResolver.activePoints(in: trip)
        return catalog.questions
            .sorted { $0.priority < $1.priority }
            .filter { question in
                (role == nil || question.role == role)
                    && conditionHolds(question.when, in: trip)
                    && collectionTimingHasArrived(
                        question.target,
                        trip: trip,
                        leg: leg,
                        activeDecisionPoints: points
                    )
            }
    }

    static func isConfirmed(_ target: QuestionTarget, trip: Trip, leg: Leg) -> Bool {
        switch target {
        case .legScheduledAt:
            return leg.scheduledAt.status == .confirmed
        case .legTransportMode:
            return leg.transportMode.status == .confirmed
        case .legReservationStatus:
            return leg.reservation.status.status == .confirmed
        case .legReservationService:
            return leg.reservation.service.status == .confirmed
        case .legBaggagePresence:
            return leg.baggagePresence.status == .confirmed
        case .bagDimensions:
            return !focusBags(in: trip, leg: leg).isEmpty
                && focusBags(in: trip, leg: leg).allSatisfy { $0.dimensions.status == .confirmed }
        }
    }

    static func conditionHolds(
        _ condition: QuestionCondition,
        in trip: Trip
    ) -> Bool {
        guard let leg = try? trip.focusLeg() else {
            return false
        }
        switch condition {
        case .always:
            return true
        case .reservationStatusIs(let status):
            return leg.reservation.status.status == .confirmed && leg.reservation.status.value == status
        case .transportIs(let mode):
            return leg.transportMode.status == .confirmed && leg.transportMode.value == mode
        case .policyNeedsDimensions:
            return DecisionPointResolver.needsBaggageDimensions(in: trip)
        }
    }

    static func isSatisfied(_ target: QuestionTarget, trip: Trip, leg: Leg) -> Bool {
        switch target {
        case .legScheduledAt:
            return leg.scheduledAt.isSatisfiedForQuestioning
        case .legTransportMode:
            return leg.transportMode.isSatisfiedForQuestioning
        case .legReservationStatus:
            return leg.reservation.status.isSatisfiedForQuestioning
        case .legReservationService:
            return leg.reservation.service.isSatisfiedForQuestioning
        case .legBaggagePresence:
            return leg.baggagePresence.isSatisfiedForQuestioning
        case .bagDimensions:
            return focusBags(in: trip, leg: leg).allSatisfy(\.dimensions.isSatisfiedForQuestioning)
                && !focusBags(in: trip, leg: leg).isEmpty
        }
    }

    private static func collectionTimingHasArrived(
        _ target: QuestionTarget,
        trip: Trip,
        leg: Leg,
        activeDecisionPoints: Set<DecisionPointID>
    ) -> Bool {
        switch target {
        case .legScheduledAt:
            return leg.scheduledAt.collectionTimingHasArrived(activeDecisionPoints: activeDecisionPoints)
        case .legTransportMode:
            return leg.transportMode.collectionTimingHasArrived(activeDecisionPoints: activeDecisionPoints)
        case .legReservationStatus:
            return leg.reservation.status.collectionTimingHasArrived(activeDecisionPoints: activeDecisionPoints)
        case .legReservationService:
            return leg.reservation.service.collectionTimingHasArrived(activeDecisionPoints: activeDecisionPoints)
        case .legBaggagePresence:
            return leg.baggagePresence.collectionTimingHasArrived(activeDecisionPoints: activeDecisionPoints)
        case .bagDimensions:
            return focusBags(in: trip, leg: leg).allSatisfy {
                $0.dimensions.collectionTimingHasArrived(activeDecisionPoints: activeDecisionPoints)
            }
        }
    }

    private static func focusBags(in trip: Trip, leg: Leg) -> [Bag] {
        leg.bagIDs.compactMap { bagID in
            trip.baggageInventory.first { $0.id == bagID }
        }
    }
}
