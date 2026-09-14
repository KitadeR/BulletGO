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
        var includeSummary = false
        var skipDerivedPipeline = false

        switch command {
        case .answerQuestion(let questionID, let answer):
            guard let spec = catalog.spec(id: questionID) else {
                throw EngineError.unknownQuestion(questionID.rawValue)
            }
            let mutations = try QuestionAnswerMapper.mutations(for: spec, answer: answer, trip: working)
            let applied = try TripMutationTransaction.apply(mutations, to: working, at: now)
            working = applied.trip
            impact = applied.impact
            includeSummary = true
        case .applyMutation(let mutation):
            if case .cacheConnectorEstimate = mutation {
                working = try TripMutationApplier.apply(mutation, to: working, at: now, validate: true)
                skipDerivedPipeline = true
            } else {
                let applied = try TripMutationTransaction.apply([mutation], to: working, at: now)
                working = applied.trip
                impact = applied.impact
                includeSummary = mutation.recordsChangeEvent
            }
        case .applyMutations(let mutations):
            if mutations.count == 1, case .cacheConnectorEstimate = mutations[0] {
                working = try TripMutationApplier.apply(mutations[0], to: working, at: now, validate: true)
                skipDerivedPipeline = true
            } else {
                let applied = try TripMutationTransaction.apply(mutations, to: working, at: now)
                working = applied.trip
                impact = applied.impact
                includeSummary = mutations.contains(where: \.recordsChangeEvent)
            }
        case .applyPhaseEvent(let event):
            working = try PhaseEngine.apply(event, to: working)
            working.updatedAt = now
        case .reachDecisionPoint(let point):
            try DecisionPointResolver.validate(point)
            reachedDecisionPoints.insert(point)
        case .focusLeg(let legID):
            guard working.legs.contains(where: { $0.id == legID }) else {
                throw EngineError.unknownLeg
            }
            working.currentContext.focus = .leg(legID)
            working.updatedAt = now
        case .reevaluate:
            break
        }

        let actions: [ActionRequirement]
        if skipDerivedPipeline {
            actions = []
        } else {
            let phaseResult = try PhaseEngine.applyAutomaticTransition(to: working)
            working = phaseResult.0
            let recalcIDs = recalcLegIDs(impact: impact, trip: working, command: command)
            working = try ShinkansenBaggageRuleEngine.evaluate(working, pack: pack, at: now, legIDs: recalcIDs)

            var desiredTasks: [TripTask] = []
            for legID in recalcIDs {
                let legActions = ActionResolver.resolve(trip: working, pack: pack, legID: legID)
                desiredTasks.append(contentsOf: try TripTaskGenerator.generate(
                    actions: legActions,
                    trip: working,
                    pack: pack,
                    legID: legID
                ))
            }
            if !recalcIDs.isEmpty {
                working.tasks = TaskReconciler.reconcile(
                    existing: working.tasks,
                    desired: desiredTasks,
                    targetLegIDs: Set(recalcIDs),
                    impact: impact
                )
            }

            actions = working.focusLegID.map { ActionResolver.resolve(trip: working, pack: pack, legID: $0) } ?? []

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
            working.currentContext.tripPhase = TripPhaseResolver.resolve(trip: working, now: now)

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

        try working.validate()
        return BrainResult(
            updatedTrip: working,
            nextQuestion: nil,
            displaySnapshot: TaskDisplayPipeline.snapshot(for: working),
            deferredSnapshot: DeferredPresentationProjector.snapshot(for: working),
            understandingSummary: nil,
            phaseProposal: nil,
            actions: []
        )
    }

    private func recalcLegIDs(impact: ImpactAssessment, trip: Trip, command: TypedCommand) -> [LegID] {
        let resolved = impact.resolvedLegIDs(in: trip)
        if !resolved.isEmpty {
            return resolved
        }
        switch command {
        case .answerQuestion, .focusLeg, .reevaluate, .applyPhaseEvent:
            return trip.focusLegID.map { [$0] } ?? []
        default:
            return []
        }
    }
}
