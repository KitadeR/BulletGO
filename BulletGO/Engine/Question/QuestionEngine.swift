import Foundation

nonisolated enum QuestionEngine {
    static func nextQuestion(in trip: Trip, catalog: QuestionCatalog) -> QuestionSpec? {
        guard let leg = try? trip.focusLeg() else {
            return nil
        }
        return catalog.questions
            .sorted { $0.priority < $1.priority }
            .first { question in
                conditionHolds(question.when, leg: leg)
                    && !isSatisfied(question.target, trip: trip, leg: leg)
            }
    }

    static func conditionHolds(_ condition: QuestionCondition, leg: Leg) -> Bool {
        switch condition {
        case .always:
            return true
        case .reservationStatusIs(let status):
            return leg.reservation.status.status == .confirmed && leg.reservation.status.value == status
        case .transportIs(let mode):
            return leg.transportMode.status == .confirmed && leg.transportMode.value == mode
        case .policyNeedsDimensions:
            return leg.policyEvaluations.contains { evaluation in
                evaluation.status == .needsMoreInformation
                    && evaluation.missingFieldPaths.contains(where: isBagDimensionsPath)
            }
        }
    }

    private static func isSatisfied(_ target: QuestionTarget, trip: Trip, leg: Leg) -> Bool {
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

    private static func focusBags(in trip: Trip, leg: Leg) -> [Bag] {
        leg.bagIDs.compactMap { bagID in
            trip.baggageInventory.first { $0.id == bagID }
        }
    }

    private static func isBagDimensionsPath(_ path: DomainPath) -> Bool {
        if case .bag(_, .dimensions) = path {
            return true
        }
        return false
    }
}
