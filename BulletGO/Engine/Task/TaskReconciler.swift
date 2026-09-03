import Foundation

nonisolated enum TaskReconciler {
    static func reconcile(
        existing: [TripTask],
        desired: [TripTask],
        focusLegID: LegID,
        impact: ImpactAssessment
    ) -> [TripTask] {
        let untouched = existing.filter { !isFocusTask($0, focusLegID: focusLegID) }
        let existingFocus = existing.filter { isFocusTask($0, focusLegID: focusLegID) }
        var used = Set<TaskID>()
        var reconciled: [TripTask] = []

        for incoming in desired {
            if let match = existingFocus.first(where: { task in
                !used.contains(task.id) && identityMatches(task, incoming)
            }) {
                used.insert(match.id)
                reconciled.append(merge(existing: match, desired: incoming, impact: impact))
            } else {
                reconciled.append(incoming)
            }
        }

        for leftover in existingFocus where !used.contains(leftover.id) {
            var cancelled = leftover
            if leftover.state != .cancelled {
                cancelled.state = .cancelled
            }
            reconciled.append(cancelled)
        }

        return untouched + reconciled
    }

    private static func isFocusTask(_ task: TripTask, focusLegID: LegID) -> Bool {
        if case .leg(let id) = task.scope {
            return id == focusLegID
        }
        return false
    }

    private static func identityMatches(_ lhs: TripTask, _ rhs: TripTask) -> Bool {
        lhs.contentKey == rhs.contentKey
            && lhs.scope == rhs.scope
            && lhs.relatedPolicyID == rhs.relatedPolicyID
    }

    private static func merge(existing: TripTask, desired: TripTask, impact: ImpactAssessment) -> TripTask {
        var merged = desired
        merged = TripTask(
            id: existing.id,
            contentKey: desired.contentKey,
            type: desired.type,
            state: revivedState(existing: existing, impact: impact),
            importance: desired.importance,
            relevantPhases: desired.relevantPhases,
            deadline: desired.deadline,
            dependencies: desired.dependencies,
            evidence: existing.evidence,
            scope: desired.scope,
            relatedActionID: existing.relatedActionID ?? desired.relatedActionID,
            relatedPolicyID: desired.relatedPolicyID,
            relatedGuideID: existing.relatedGuideID ?? desired.relatedGuideID,
            completionCondition: desired.completionCondition
        )
        return merged
    }

    private static func revivedState(existing: TripTask, impact: ImpactAssessment) -> TaskState {
        if existing.state == .cancelled {
            return .notStarted
        }
        if existing.state == .completed {
            let dependencyChanged = existing.dependencies.contains { dependency in
                impact.changedPaths.contains(dependency.path)
            }
            return dependencyChanged ? .needsReview : .completed
        }
        return existing.state
    }
}
