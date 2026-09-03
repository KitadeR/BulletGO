import Foundation

nonisolated enum DecisionPointResolver {
    static func activePoints(in trip: Trip, reached: Set<DecisionPointID> = []) -> Set<DecisionPointID> {
        var points = reached.intersection([.seatSelection, .baggagePolicyEvaluation])
        if needsBaggageDimensions(in: trip) {
            points.insert(.baggagePolicyEvaluation)
        }
        return points
    }

    static func needsBaggageDimensions(in trip: Trip) -> Bool {
        guard let leg = try? trip.focusLeg() else {
            return false
        }
        return leg.policyEvaluations.contains { evaluation in
            evaluation.status == .needsMoreInformation
                && evaluation.missingFieldPaths.contains(where: isBagDimensionsPath)
        }
    }

    static func validate(_ decisionPoint: DecisionPointID) throws {
        switch decisionPoint {
        case .seatSelection, .baggagePolicyEvaluation:
            return
        default:
            throw EngineError.unknownDecisionPoint(decisionPoint.rawValue)
        }
    }

    private static func isBagDimensionsPath(_ path: DomainPath) -> Bool {
        if case .bag(_, .dimensions) = path {
            return true
        }
        return false
    }
}
