import Foundation

nonisolated struct BrainResult: Hashable, Sendable {
    var updatedTrip: Trip
    var nextQuestion: QuestionSpec?
    var displaySnapshot: TaskDisplaySnapshot
    var phaseProposal: PhaseProposal?
    var actions: [ActionRequirement]
}

nonisolated struct TripBrain: Sendable {
    var catalog: QuestionCatalog
    var pack: BaggagePolicyPack
    var clock: EngineClock

    init(catalog: QuestionCatalog, pack: BaggagePolicyPack, clock: EngineClock = .system) {
        self.catalog = catalog
        self.pack = pack
        self.clock = clock
    }

    func process(trip: Trip, command: TypedCommand) throws -> BrainResult {
        let now = clock.now()
        var working = trip
        var impact = ImpactAssessment(level: .low, targetLegs: [], changedPaths: [])

        switch command {
        case .answerQuestion(let questionID, let answer):
            guard let spec = catalog.spec(id: questionID) else {
                throw EngineError.unknownQuestion(questionID.rawValue)
            }
            let mutations = try QuestionAnswerMapper.mutations(for: spec, answer: answer, trip: working)
            for mutation in mutations {
                let analyzed = ImpactAnalyzer.analyze(mutation)
                impact = merge(impact, analyzed.assessment)
                working = try TripMutationApplier.apply(mutation, to: working, at: now)
            }
        case .applyMutation(let mutation):
            impact = ImpactAnalyzer.analyze(mutation).assessment
            working = try TripMutationApplier.apply(mutation, to: working, at: now)
        case .applyPhaseEvent(let event):
            working = try PhaseEngine.apply(event, to: working)
            working.updatedAt = now
        case .reevaluate:
            break
        }

        let phaseResult = try PhaseEngine.applyAutomaticTransition(to: working)
        working = phaseResult.0
        working = try ShinkansenBaggageRuleEngine.evaluate(working, pack: pack, at: now)
        let actions = ActionResolver.resolve(trip: working, pack: pack)
        if let focusID = working.focusLegID {
            let desired = try TripTaskGenerator.generate(actions: actions, trip: working, pack: pack)
            working.tasks = TaskReconciler.reconcile(
                existing: working.tasks,
                desired: desired,
                focusLegID: focusID,
                impact: impact
            )
        }
        try working.validate()
        return BrainResult(
            updatedTrip: working,
            nextQuestion: QuestionEngine.nextQuestion(in: working, catalog: catalog),
            displaySnapshot: TaskDisplayPipeline.snapshot(for: working),
            phaseProposal: phaseResult.1,
            actions: actions
        )
    }

    private func merge(_ lhs: ImpactAssessment, _ rhs: ImpactAssessment) -> ImpactAssessment {
        ImpactAssessment(
            level: [lhs.level, rhs.level].max(by: { rank($0) < rank($1) }) ?? rhs.level,
            targetLegs: Array(Set(lhs.targetLegs + rhs.targetLegs)),
            changedPaths: lhs.changedPaths + rhs.changedPaths.filter { !lhs.changedPaths.contains($0) }
        )
    }

    private func rank(_ level: ChangeImpactLevel) -> Int {
        switch level {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }
}
