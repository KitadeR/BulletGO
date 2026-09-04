import Foundation

nonisolated enum TripTaskGenerator {
    static func generate(
        actions: [ActionRequirement],
        trip: Trip,
        pack: BaggagePolicyPack
    ) throws -> [TripTask] {
        let leg = try trip.focusLeg()
        return actions.compactMap { action in
            guard let template = pack.taskTemplate(contentKey: action.purposeKey) else {
                return nil
            }
            return TripTask(
                id: TaskID(),
                contentKey: template.contentKey,
                type: template.type,
                state: .notStarted,
                importance: template.importance,
                relevantPhases: template.relevantPhases,
                deadline: leg.scheduledAt.status == .confirmed ? leg.scheduledAt.value : nil,
                dependencies: dependencies(for: action.purposeKey, trip: trip, leg: leg),
                evidence: .none,
                scope: .leg(leg.id),
                relatedActionID: action.id,
                relatedPolicyID: pack.id,
                relatedGuideID: template.contentKey == ActionPurpose.captureDimensions
                    ? .shinkansenBaggageMeasurement
                    : nil,
                completionCondition: template.completionCondition
            )
        }
    }

    private static func dependencies(for purposeKey: String, trip: Trip, leg: Leg) -> [TaskDependency] {
        switch purposeKey {
        case ActionPurpose.reserveOversizedSeat:
            leg.bagIDs.compactMap { bagID in
                guard trip.baggageInventory.contains(where: { $0.id == bagID }) else {
                    return nil
                }
                return TaskDependency(path: .bag(bagID, .dimensions), requiredTaskID: nil)
            }
        default:
            []
        }
    }
}
