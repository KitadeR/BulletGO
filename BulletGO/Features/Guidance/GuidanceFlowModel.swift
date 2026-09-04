import Foundation
import Observation

@MainActor
@Observable
final class GuidanceFlowModel {
    enum Stage: Equatable {
        case compose
        case interpreting
        case summary
        case setupQuestion
        case ready
        case failed
        case structuredFallback
    }

    let tripID: TripID
    let legID: LegID
    let entry: GuidanceEntry
    let completion: GuidanceCompletion

    var stage: Stage
    var draftText: String = ""
    var currentQuestion: QuestionSpec?
    var summary: UnderstandingSummary?
    var selectedChoice: String?
    var selectedDate: Date
    var didCompleteReady = false
    var shouldDismissToSource = false

    private let session: TripSessionModel
    private let timeZone: TimeZone

    init(
        tripID: TripID,
        legID: LegID,
        entry: GuidanceEntry,
        completion: GuidanceCompletion,
        session: TripSessionModel
    ) {
        self.tripID = tripID
        self.legID = legID
        self.entry = entry
        self.completion = completion
        self.session = session
        self.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        self.stage = entry == .compose ? .compose : .interpreting
        self.selectedDate = Date()
        if let start = session.trip?.startDate.value?.date(in: timeZone) {
            self.selectedDate = start
        }
    }

    var isProcessing: Bool {
        session.processState == .processing || stage == .interpreting
    }

    var exampleText: String {
        "I want to take the Shinkansen! I'd like a seat with a view of Mt. Fuji."
    }

    func start() async {
        await ensureFocus()
        switch entry {
        case .compose:
            stage = .compose
        case .resume:
            advanceFromTrip()
        }
    }

    func submitCompose() async {
        stage = .interpreting
        await ensureFocus()
        let interpretation = session.interpret(draftText, legID: legID)
        if interpretation.fallbackToStructuredQuestions {
            stage = .structuredFallback
            return
        }
        guard let result = await session.process(.applyMutations(interpretation.mutations)) else {
            stage = .failed
            return
        }
        summary = result.understandingSummary
        stage = .summary
    }

    func continueFromSummary() {
        if completion == .stayInPlace {
            shouldDismissToSource = true
            return
        }
        advanceFromTrip()
    }

    func beginStructuredQuestions() {
        if completion == .stayInPlace {
            shouldDismissToSource = true
            return
        }
        guard let trip = session.trip, let catalog = session.catalog else {
            stage = .failed
            return
        }
        if let question = QuestionEngine.nextSetupQuestion(in: trip, catalog: catalog) {
            currentQuestion = question
            selectedChoice = nil
            if question.id == .legDate, let start = trip.startDate.value?.date(in: timeZone) {
                selectedDate = start
            }
            stage = .setupQuestion
            return
        }
        advanceFromTrip()
    }

    func retryLastStep() async {
        switch entry {
        case .compose where stage == .failed:
            await submitCompose()
        default:
            await start()
        }
    }

    func confirmDate() async {
        do {
            let local = try LocalDate(date: selectedDate, timeZone: timeZone)
            let moment = try ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier)
            await answer(.scheduledMoment(moment))
        } catch {
            stage = .failed
        }
    }

    func confirmChoice(_ value: String) async {
        selectedChoice = value
        await answer(.choice(value))
    }

    func skipCurrent() async {
        guard let question = currentQuestion else {
            return
        }
        switch question.id {
        case .ticketStatus:
            await answer(.choice("unsure"))
        case .luggagePresence:
            await answer(.choice("skip"))
        default:
            dismissWithoutReady()
        }
    }

    func answeredQuestions() -> [QuestionSpec] {
        guard let trip = session.trip,
              let catalog = session.catalog,
              let leg = trip.legs.first(where: { $0.id == legID })
        else {
            return []
        }
        return QuestionEngine.applicableQuestions(
            in: trip,
            catalog: catalog,
            role: .setup
        ).filter { question in
            QuestionEngine.isSatisfied(question.target, trip: trip, leg: leg)
                && question.id != currentQuestion?.id
        }
    }

    func answerValue(for question: QuestionSpec) -> DisplayText {
        guard let trip = session.trip, let leg = trip.legs.first(where: { $0.id == legID }) else {
            return .verbatim("")
        }
        switch question.target {
        case .legScheduledAt:
            if let date = leg.scheduledAt.value?.date {
                return .verbatim("\(date.year)/\(date.month)/\(date.day)")
            }
        case .legTransportMode:
            return .localized(TripContentResolver.transportSummary(for: leg))
        case .legReservationStatus:
            if let status = leg.reservation.status.value {
                return TripContentResolver.summaryValue(
                    UnderstandingSummaryItem(
                        contentKey: "leg.reservationStatus",
                        scope: .leg(leg.id),
                        path: .leg(leg.id, .reservation),
                        value: .reservationStatus(status),
                        relatedQuestionID: .ticketStatus,
                        relatedDecisionPointID: nil
                    )
                )
            }
        case .legBaggagePresence:
            if let presence = leg.baggagePresence.value {
                return TripContentResolver.summaryValue(
                    UnderstandingSummaryItem(
                        contentKey: "leg.baggagePresence",
                        scope: .leg(leg.id),
                        path: .leg(leg.id, .baggagePresence),
                        value: .baggagePresence(presence),
                        relatedQuestionID: .luggagePresence,
                        relatedDecisionPointID: nil
                    )
                )
            }
        default:
            break
        }
        return .localized(
            LocalizedStringResource("Saved", comment: "Collapsed answer fallback when a value is deferred.")
        )
    }

    private func answer(_ answer: QuestionAnswer) async {
        guard let question = currentQuestion else {
            return
        }
        await ensureFocus()
        guard await session.process(.answerQuestion(question.id, answer)) != nil else {
            stage = .failed
            return
        }
        advanceFromTrip()
    }

    private func advanceFromTrip() {
        guard let trip = session.trip, let catalog = session.catalog else {
            stage = .failed
            return
        }
        switch GuidanceProgressEvaluator.evaluate(trip: trip, catalog: catalog) {
        case .needsSetup(let question), .paused(let question):
            currentQuestion = question
            selectedChoice = nil
            if question.id == .legDate, let start = trip.startDate.value?.date(in: timeZone) {
                selectedDate = start
            }
            stage = .setupQuestion
        case .ready:
            currentQuestion = nil
            stage = .ready
            didCompleteReady = true
            if completion == .stayInPlace {
                shouldDismissToSource = true
            }
        case .notStarted:
            stage = .compose
        }
    }

    private func dismissWithoutReady() {
        currentQuestion = nil
        stage = .compose
    }

    private func ensureFocus() async {
        guard session.trip?.focusLegID != legID else {
            return
        }
        _ = await session.process(.focusLeg(legID))
    }
}
