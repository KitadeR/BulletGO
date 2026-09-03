import Foundation

nonisolated struct BrainResult: Hashable, Sendable {
    var updatedTrip: Trip
    var nextQuestion: QuestionSpec?
    var displaySnapshot: TaskDisplaySnapshot
    var deferredSnapshot: DeferredPresentationSnapshot
    var understandingSummary: UnderstandingSummary?
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
        let before = trip
        var working = trip
        var impact = ImpactAssessment(level: .low, targetLegs: [], changedPaths: [])
        var reachedDecisionPoints: Set<DecisionPointID> = []
        let includeSummary: Bool

        switch command {
        case .answerQuestion(let questionID, let answer):
            guard let spec = catalog.spec(id: questionID) else {
                throw EngineError.unknownQuestion(questionID.rawValue)
            }
            let mutations = try QuestionAnswerMapper.mutations(for: spec, answer: answer, trip: working)
            (working, impact) = try applyMutations(mutations, to: working, impact: impact, at: now)
            includeSummary = true
        case .applyMutation(let mutation):
            (working, impact) = try applyMutations([mutation], to: working, impact: impact, at: now)
            includeSummary = true
        case .applyMutations(let mutations):
            (working, impact) = try applyMutations(mutations, to: working, impact: impact, at: now)
            includeSummary = true
        case .applyPhaseEvent(let event):
            working = try PhaseEngine.apply(event, to: working)
            working.updatedAt = now
            includeSummary = false
        case .reachDecisionPoint(let point):
            try DecisionPointResolver.validate(point)
            reachedDecisionPoints.insert(point)
            includeSummary = false
        case .reevaluate:
            includeSummary = false
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

        let activeDecisionPoints = DecisionPointResolver.activePoints(
            in: working,
            reached: reachedDecisionPoints
        )
        working = try DeferredPresentationEngine.apply(
            to: working,
            activeDecisionPoints: activeDecisionPoints,
            at: now
        )
        try working.validate()

        let understandingSummary: UnderstandingSummary?
        if includeSummary {
            understandingSummary = UnderstandingSummaryBuilder.build(
                before: before,
                after: working,
                changedPaths: impact.changedPaths,
                catalog: catalog,
                activeDecisionPoints: activeDecisionPoints
            )
        } else {
            understandingSummary = nil
        }

        return BrainResult(
            updatedTrip: working,
            nextQuestion: QuestionEngine.nextQuestion(
                in: working,
                catalog: catalog,
                activeDecisionPoints: activeDecisionPoints
            ),
            displaySnapshot: TaskDisplayPipeline.snapshot(for: working),
            deferredSnapshot: DeferredPresentationProjector.snapshot(for: working),
            understandingSummary: understandingSummary,
            phaseProposal: phaseResult.1,
            actions: actions
        )
    }

    private func applyMutations(
        _ mutations: [TripMutation],
        to trip: Trip,
        impact: ImpactAssessment,
        at now: Date
    ) throws -> (Trip, ImpactAssessment) {
        var working = trip
        var merged = impact
        for mutation in mutations {
            let analyzed = ImpactAnalyzer.analyze(mutation)
            merged = merge(merged, analyzed.assessment)
            working = try TripMutationApplier.apply(mutation, to: working, at: now)
        }
        return (working, merged)
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
