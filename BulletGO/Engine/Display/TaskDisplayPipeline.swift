import Foundation

nonisolated struct TaskDisplaySnapshot: Hashable, Sendable {
    var now: [TaskID]
    var next: [TaskID]
    var later: [TaskID]
    var hidden: [TaskID]
}

nonisolated enum TaskDisplayPipeline {
    static let nowLimit = 3

    static func snapshot(for trip: Trip) -> TaskDisplaySnapshot {
        let phase = (try? trip.focusLeg())?.phase
        var hidden: [TaskID] = []
        var eligible: [TripTask] = []
        var waiting: [TripTask] = []

        for task in trip.tasks {
            if isHidden(task) {
                hidden.append(task.id)
            } else if dependenciesSatisfied(task, trip: trip) {
                eligible.append(task)
            } else {
                waiting.append(task)
            }
        }

        let ranked = eligible.sorted { lhs, rhs in
            compare(lhs, rhs, trip: trip, phase: phase)
        }
        let now = Array(ranked.prefix(Self.nowLimit)).map(\.id)
        let remaining = ranked.dropFirst(min(Self.nowLimit, ranked.count))
        var next: [TaskID] = []
        var later: [TaskID] = []
        for task in Array(remaining) + waiting {
            if isRelevant(task, phase: phase) {
                next.append(task.id)
            } else {
                later.append(task.id)
            }
        }
        return TaskDisplaySnapshot(now: now, next: next, later: later, hidden: hidden)
    }

    private static func isHidden(_ task: TripTask) -> Bool {
        switch task.state {
        case .completed, .cancelled, .stale, .skipped:
            true
        case .notStarted, .inProgress, .needsReview, .blocked:
            false
        }
    }

    private static func isRelevant(_ task: TripTask, phase: LegPhase?) -> Bool {
        guard let phase else {
            return true
        }
        return task.relevantPhases.isEmpty || task.relevantPhases.contains(phase)
    }

    private static func compare(_ lhs: TripTask, _ rhs: TripTask, trip: Trip, phase: LegPhase?) -> Bool {
        let boost = { (task: TripTask) -> Int in
            var score = 0
            if task.state == .needsReview {
                score -= 2
            }
            if hasActionRequiredReadiness(for: task, trip: trip) {
                score -= 1
            }
            return score
        }
        let lhsBoost = boost(lhs)
        let rhsBoost = boost(rhs)
        if lhsBoost != rhsBoost {
            return lhsBoost < rhsBoost
        }
        let lhsRelevant = isRelevant(lhs, phase: phase)
        let rhsRelevant = isRelevant(rhs, phase: phase)
        if lhsRelevant != rhsRelevant {
            return lhsRelevant && !rhsRelevant
        }
        let lhsDeadline = deadlineOrder(lhs.deadline)
        let rhsDeadline = deadlineOrder(rhs.deadline)
        if lhsDeadline != rhsDeadline {
            return lhsDeadline < rhsDeadline
        }
        let lhsImportance = importanceOrder(lhs.importance)
        let rhsImportance = importanceOrder(rhs.importance)
        if lhsImportance != rhsImportance {
            return lhsImportance < rhsImportance
        }
        return lhs.dependencies.count < rhs.dependencies.count
    }

    private static func hasActionRequiredReadiness(for task: TripTask, trip: Trip) -> Bool {
        trip.readinessChecks.contains { check in
            check.scope == task.scope && check.status == .actionRequired && !check.stale
        }
    }

    private static func importanceOrder(_ importance: TaskImportance) -> Int {
        switch importance {
        case .required: 0
        case .important: 1
        case .recommended: 2
        case .optional: 3
        }
    }

    private static func deadlineOrder(_ deadline: ScheduledMoment?) -> (Int, Int, Int, Int, Int, Int) {
        guard let deadline else {
            return (9_999, 12, 31, 23, 59, 59)
        }
        return (
            deadline.date.year,
            deadline.date.month,
            deadline.date.day,
            deadline.time?.hour ?? 23,
            deadline.time?.minute ?? 59,
            deadline.time?.second ?? 59
        )
    }

    private static func dependenciesSatisfied(_ task: TripTask, trip: Trip) -> Bool {
        task.dependencies.allSatisfy { dependency in
            if let requiredID = dependency.requiredTaskID {
                guard let required = trip.tasks.first(where: { $0.id == requiredID }),
                      required.state == .completed
                else {
                    return false
                }
            }
            return pathSatisfied(dependency.path, trip: trip)
        }
    }

    private static func pathSatisfied(_ path: DomainPath, trip: Trip) -> Bool {
        switch path {
        case .leg(let id, let field):
            guard let leg = trip.legs.first(where: { $0.id == id }) else {
                return false
            }
            switch field {
            case .origin: return leg.origin.isSatisfiedForQuestioning
            case .destination: return leg.destination.isSatisfiedForQuestioning
            case .scheduledAt: return leg.scheduledAt.isSatisfiedForQuestioning
            case .transportMode: return leg.transportMode.isSatisfiedForQuestioning
            case .partyCount: return leg.partyCount.isSatisfiedForQuestioning
            case .baggagePresence: return leg.baggagePresence.isSatisfiedForQuestioning
            case .bagIDs: return !leg.bagIDs.isEmpty
            case .reservation: return leg.reservation.status.isSatisfiedForQuestioning
            case .phase: return true
            }
        case .bag(let id, let field):
            guard let bag = trip.baggageInventory.first(where: { $0.id == id }) else {
                return false
            }
            switch field {
            case .kind: return bag.kind.isSatisfiedForQuestioning
            case .userDescription: return bag.userDescription.isSatisfiedForQuestioning
            case .perceivedSize: return bag.perceivedSize.isSatisfiedForQuestioning
            case .dimensions: return bag.dimensions.isSatisfiedForQuestioning
            case .weight: return bag.weightKilograms.isSatisfiedForQuestioning
            }
        default:
            return true
        }
    }
}
