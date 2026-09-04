import Foundation

nonisolated enum LegDetailMode: Equatable, Sendable {
    case setup
    case cockpit
}

nonisolated struct LegSetupStep: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case completed
        case deferred
        case current
        case upcoming
    }

    var question: QuestionSpec
    var kind: Kind
    var title: LocalizedStringResource
    var prompt: LocalizedStringResource
    var valueText: DisplayText?
    var systemImage: String
    var stepNumber: Int

    var id: QuestionID { question.id }

    static func == (lhs: LegSetupStep, rhs: LegSetupStep) -> Bool {
        lhs.question == rhs.question
            && lhs.kind == rhs.kind
            && lhs.title.key == rhs.title.key
            && lhs.prompt.key == rhs.prompt.key
            && lhs.valueText == rhs.valueText
            && lhs.systemImage == rhs.systemImage
            && lhs.stepNumber == rhs.stepNumber
    }
}

nonisolated struct LegSetupSnapshot: Equatable, Sendable {
    var title: String
    var steps: [LegSetupStep]
    var currentQuestionID: QuestionID?
    var isPaused: Bool
}

nonisolated struct LegDetailSnapshot: Equatable, Sendable {
    var mode: LegDetailMode
    var title: String
    var setup: LegSetupSnapshot?
    var cockpit: LegCockpitSnapshot?
}

nonisolated struct LegCockpitSnapshot: Equatable, Sendable {
    var title: String
    var dateText: String?
    var timeText: String?
    var transport: DisplayText
    var reservationStatus: DisplayText
    var reservationService: DisplayText?
    var bookingReadiness: PreparationStatusKind
    var luggageReadiness: PreparationStatusKind
    var whatsNext: TimelineNowItem?
    var needsSetup: Bool
}

nonisolated enum LegDetailComposer {
    static func snapshot(
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?
    ) -> LegDetailSnapshot {
        let title = "\(leg.origin.value ?? "") → \(leg.destination.value ?? "")"
        let focused = focusedTrip(trip, legID: leg.id)
        let cockpit = LegCockpitComposer.snapshot(trip: focused, leg: focusedLeg(focused, fallback: leg), catalog: catalog)
        guard let catalog else {
            return LegDetailSnapshot(mode: .cockpit, title: title, setup: nil, cockpit: cockpit)
        }

        switch GuidanceProgressEvaluator.evaluate(trip: focused, catalog: catalog) {
        case .ready:
            return LegDetailSnapshot(mode: .cockpit, title: title, setup: nil, cockpit: cockpit)
        case .notStarted, .needsSetup, .paused:
            return LegDetailSnapshot(
                mode: .setup,
                title: title,
                setup: setupSnapshot(trip: focused, title: title, catalog: catalog),
                cockpit: nil
            )
        }
    }

    private static func setupSnapshot(
        trip: Trip,
        title: String,
        catalog: QuestionCatalog
    ) -> LegSetupSnapshot {
        let questions = QuestionEngine.applicableQuestions(in: trip, catalog: catalog, role: .setup)
        let nextID = QuestionEngine.nextSetupQuestion(in: trip, catalog: catalog)?.id
        let leg = (try? trip.focusLeg()) ?? trip.legs[0]
        let steps = questions.enumerated().map { index, question in
            step(
                question: question,
                stepNumber: index + 1,
                nextID: nextID,
                trip: trip,
                leg: leg
            )
        }
        return LegSetupSnapshot(
            title: title,
            steps: steps,
            currentQuestionID: nextID,
            isPaused: nextID == nil
        )
    }

    private static func step(
        question: QuestionSpec,
        stepNumber: Int,
        nextID: QuestionID?,
        trip: Trip,
        leg: Leg
    ) -> LegSetupStep {
        let confirmed = QuestionEngine.isConfirmed(question.target, trip: trip, leg: leg)
        let satisfied = QuestionEngine.isSatisfied(question.target, trip: trip, leg: leg)
        let kind: LegSetupStep.Kind
        if question.id == nextID {
            kind = .current
        } else if confirmed {
            kind = .completed
        } else if satisfied {
            kind = .deferred
        } else {
            kind = .upcoming
        }
        let value: DisplayText?
        switch kind {
        case .completed:
            value = TripContentResolver.setupStepValue(question: question, trip: trip, leg: leg)
        case .deferred:
            value = TripContentResolver.deferredSetupValue()
        case .current, .upcoming:
            value = nil
        }
        return LegSetupStep(
            question: question,
            kind: kind,
            title: TripContentResolver.setupStepTitle(question),
            prompt: TripContentResolver.setupQuestionPrompt(question, leg: leg),
            valueText: value,
            systemImage: TripContentResolver.setupStepSystemImage(question, leg: leg),
            stepNumber: stepNumber
        )
    }

    static func focusedTrip(_ trip: Trip, legID: LegID) -> Trip {
        var copy = trip
        copy.currentContext.focus = .leg(legID)
        return copy
    }

    private static func focusedLeg(_ trip: Trip, fallback: Leg) -> Leg {
        (try? trip.focusLeg()) ?? fallback
    }
}

nonisolated enum LegCockpitComposer {
    static func snapshot(
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?
    ) -> LegCockpitSnapshot {
        LegCockpitSnapshot(
            title: "\(leg.origin.value ?? "") → \(leg.destination.value ?? "")",
            dateText: dateText(leg),
            timeText: timeText(leg),
            transport: .localized(TripContentResolver.transportSummary(for: leg)),
            reservationStatus: .localized(TripContentResolver.reservationStatusText(leg.reservation)),
            reservationService: TripContentResolver.bookingServiceText(leg.reservation).map(DisplayText.localized),
            bookingReadiness: bookingReadiness(trip: trip, leg: leg),
            luggageReadiness: luggageReadiness(trip: trip, leg: leg),
            whatsNext: whatsNext(trip: trip, leg: leg, catalog: catalog),
            needsSetup: needsSetup(trip: trip, leg: leg, catalog: catalog)
        )
    }

    static func bookingReadiness(trip: Trip, leg: Leg) -> PreparationStatusKind {
        let checks = trip.readinessChecks.filter {
            $0.scope == .leg(leg.id) && !$0.stale && $0.checkType == .ticketIssuance
        }
        if checks.contains(where: { $0.status == .actionRequired }) {
            return .actionRequired
        }
        if checks.contains(where: { $0.status == .needsMoreInfo }) {
            return .needsDetail
        }
        if !checks.isEmpty, checks.allSatisfy({ $0.status == .ready || $0.status == .notApplicable }) {
            return .ready
        }
        return .unverified
    }

    static func luggageReadiness(trip: Trip, leg: Leg) -> PreparationStatusKind {
        let baggageChecks = trip.readinessChecks.filter {
            $0.scope == .leg(leg.id) && !$0.stale && $0.checkType == .baggageReservation
        }
        if !baggageChecks.isEmpty {
            if baggageChecks.contains(where: { $0.status == .actionRequired }) {
                return .actionRequired
            }
            if baggageChecks.contains(where: { $0.status == .needsMoreInfo }) {
                return .needsDetail
            }
            if baggageChecks.allSatisfy({ $0.status == .ready || $0.status == .notApplicable }) {
                return .ready
            }
            return .unverified
        }
        if let evaluation = leg.policyEvaluations.first(where: { $0.status != .stale }) {
            switch evaluation.status {
            case .needsMoreInformation:
                return .needsDetail
            case .unevaluated, .evaluated, .stale:
                return .unverified
            }
        }
        return .unverified
    }

    private static func whatsNext(
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?
    ) -> TimelineNowItem? {
        let items = TimelineNowComposer.items(for: trip, catalog: catalog).filter { item in
            switch item.kind {
            case .task(let taskID):
                guard let task = trip.tasks.first(where: { $0.id == taskID }) else {
                    return false
                }
                if case .leg(let id) = task.scope {
                    return id == leg.id
                }
                return false
            case .resume(let legID):
                return legID == leg.id
            }
        }
        return items.first.map { HomePrimaryActionComposer.routed($0, trip: trip) }
    }

    private static func needsSetup(trip: Trip, leg: Leg, catalog: QuestionCatalog?) -> Bool {
        guard let catalog, trip.focusLegID == leg.id else {
            return false
        }
        switch GuidanceProgressEvaluator.evaluate(trip: trip, catalog: catalog) {
        case .ready:
            return false
        case .notStarted, .needsSetup, .paused:
            return true
        }
    }

    private static func dateText(_ leg: Leg) -> String? {
        guard leg.scheduledAt.status == .confirmed, let date = leg.scheduledAt.value?.date else {
            return nil
        }
        return date.displayString
    }

    private static func timeText(_ leg: Leg) -> String? {
        guard leg.scheduledAt.status == .confirmed, let time = leg.scheduledAt.value?.time else {
            return nil
        }
        return String(format: "%02d:%02d", time.hour, time.minute)
    }
}
