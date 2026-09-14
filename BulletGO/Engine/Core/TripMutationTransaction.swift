import Foundation

nonisolated struct TripMutationTransactionResult: Sendable {
    var trip: Trip
    var impact: ImpactAssessment
}

nonisolated enum TripMutationTransaction {
    static func apply(
        _ mutations: [TripMutation],
        to trip: Trip,
        at now: Date
    ) throws -> TripMutationTransactionResult {
        var working = trip
        var merged = ImpactAssessment(level: .low, targetLegs: [], changedPaths: [])
        for mutation in mutations {
            let analyzed = ImpactAnalyzer.analyze(mutation)
            merged = merge(merged, analyzed.assessment)
            working = try TripMutationApplier.apply(mutation, to: working, at: now, validate: false)
        }
        try working.validate()
        return TripMutationTransactionResult(trip: working, impact: merged)
    }

    private static func merge(_ lhs: ImpactAssessment, _ rhs: ImpactAssessment) -> ImpactAssessment {
        ImpactAssessment(
            level: [lhs.level, rhs.level].max(by: { rank($0) < rank($1) }) ?? rhs.level,
            targetLegs: Array(Set(lhs.targetLegs + rhs.targetLegs)),
            changedPaths: lhs.changedPaths + rhs.changedPaths.filter { !lhs.changedPaths.contains($0) }
        )
    }

    private static func rank(_ level: ChangeImpactLevel) -> Int {
        switch level {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }
}
