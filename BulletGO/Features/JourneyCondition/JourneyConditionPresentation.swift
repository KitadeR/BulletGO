import Foundation

nonisolated enum JourneyConditionFactID: String, Hashable, Sendable {
    case route
    case date
    case transport
    case booking
    case luggage
}

nonisolated struct JourneyConditionFact: Identifiable, Equatable, Sendable {
    var id: JourneyConditionFactID
    var title: LocalizedStringResource
    var value: DisplayText
    var questionID: QuestionID?

    static func == (lhs: JourneyConditionFact, rhs: JourneyConditionFact) -> Bool {
        lhs.id == rhs.id
            && lhs.title.key == rhs.title.key
            && lhs.value == rhs.value
            && lhs.questionID == rhs.questionID
    }
}

nonisolated struct JourneyConditionQuestion: Equatable, Sendable {
    var spec: QuestionSpec
    var title: LocalizedStringResource
    var prompt: LocalizedStringResource
    var allowsSkip: Bool
}

nonisolated enum JourneyChapterID: String, CaseIterable, Identifiable, Sendable {
    case movement
    case conditions
    case reservation
    case boarding
    case travelDay

    var id: String { rawValue }

    var number: Int {
        switch self {
        case .movement: 1
        case .conditions: 2
        case .reservation: 3
        case .boarding: 4
        case .travelDay: 5
        }
    }
}

nonisolated struct JourneyChapterFocus: Equatable, Sendable {
    var title: LocalizedStringResource
    var why: LocalizedStringResource

    static func == (lhs: JourneyChapterFocus, rhs: JourneyChapterFocus) -> Bool {
        lhs.title.key == rhs.title.key && lhs.why.key == rhs.why.key
    }
}

nonisolated struct JourneyChapter: Identifiable, Equatable, Sendable {
    var id: JourneyChapterID
    var title: LocalizedStringResource
    var status: DisplayText
    var isOpen: Bool
    var question: JourneyConditionQuestion?
    var luggageGuide: TimelineNowItem?
    var focus: JourneyChapterFocus?
    var reopenQuestionID: QuestionID?

    static func == (lhs: JourneyChapter, rhs: JourneyChapter) -> Bool {
        lhs.id == rhs.id
            && lhs.title.key == rhs.title.key
            && lhs.status == rhs.status
            && lhs.isOpen == rhs.isOpen
            && lhs.question == rhs.question
            && lhs.luggageGuide == rhs.luggageGuide
            && lhs.focus == rhs.focus
            && lhs.reopenQuestionID == rhs.reopenQuestionID
    }
}

nonisolated struct JourneySheetItem: Equatable, Sendable {
    var id: String
    var title: LocalizedStringResource
    var why: LocalizedStringResource?

    static func == (lhs: JourneySheetItem, rhs: JourneySheetItem) -> Bool {
        lhs.id == rhs.id && lhs.title.key == rhs.title.key && lhs.why?.key == rhs.why?.key
    }
}

nonisolated struct JourneyConditionSnapshot: Equatable, Sendable {
    var title: String
    var modeTitle: LocalizedStringResource
    var metaText: String?
    var facts: [JourneyConditionFact]
    var current: JourneyConditionQuestion?
    var luggageGuide: TimelineNowItem?
    var isBookedStop: Bool
    var chapters: [JourneyChapter]
    var sheetItem: JourneySheetItem?

    static func == (lhs: JourneyConditionSnapshot, rhs: JourneyConditionSnapshot) -> Bool {
        lhs.title == rhs.title
            && lhs.modeTitle.key == rhs.modeTitle.key
            && lhs.metaText == rhs.metaText
            && lhs.facts == rhs.facts
            && lhs.current == rhs.current
            && lhs.luggageGuide == rhs.luggageGuide
            && lhs.isBookedStop == rhs.isBookedStop
            && lhs.chapters == rhs.chapters
            && lhs.sheetItem == rhs.sheetItem
    }
}

nonisolated enum JourneyConditionComposer {
    static func snapshot(
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?,
        reopenedQuestionID: QuestionID? = nil
    ) -> JourneyConditionSnapshot {
        let focused = LegDetailComposer.focusedTrip(trip, legID: leg.id)
        let focusedLeg = (try? focused.focusLeg()) ?? leg
        let current = currentQuestion(
            trip: focused,
            leg: focusedLeg,
            catalog: catalog,
            reopenedQuestionID: reopenedQuestionID
        )
        let builtFacts = facts(
            trip: focused,
            leg: focusedLeg,
            catalog: catalog,
            hiding: current?.spec.id
        )
        let guide = luggageGuide(
            trip: focused,
            leg: focusedLeg,
            hidingQuestion: current != nil
        )
        let chapters = chapters(
            trip: focused,
            leg: focusedLeg,
            facts: builtFacts,
            current: current,
            luggageGuide: guide
        )
        return JourneyConditionSnapshot(
            title: "\(focusedLeg.origin.value ?? "") → \(focusedLeg.destination.value ?? "")",
            modeTitle: modeTitle(focusedLeg),
            metaText: metaText(focusedLeg),
            facts: builtFacts,
            current: current,
            luggageGuide: guide,
            isBookedStop: isBooked(focusedLeg),
            chapters: chapters,
            sheetItem: sheetItem(in: chapters)
        )
    }

    static func continuesPreBooking(_ leg: Leg) -> Bool {
        leg.reservation.status.status == .confirmed && leg.reservation.status.value == .notBooked
    }

    static func isBooked(_ leg: Leg) -> Bool {
        leg.reservation.status.status == .confirmed && leg.reservation.status.value == .booked
    }

    private static func currentQuestion(
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?,
        reopenedQuestionID: QuestionID?
    ) -> JourneyConditionQuestion? {
        guard let catalog else {
            return nil
        }
        let questions = QuestionEngine.applicableQuestions(in: trip, catalog: catalog, role: .setup)
        if let reopenedQuestionID,
           let question = questions.first(where: { $0.id == reopenedQuestionID }),
           shouldAsk(question, leg: leg)
        {
            return makeQuestion(question, leg: leg)
        }
        guard let next = QuestionEngine.nextSetupQuestion(in: trip, catalog: catalog),
              shouldAsk(next, leg: leg)
        else {
            return nil
        }
        return makeQuestion(next, leg: leg)
    }

    private static func shouldAsk(_ question: QuestionSpec, leg: Leg) -> Bool {
        switch question.id {
        case .luggagePresence:
            continuesPreBooking(leg)
        case .selectService, .baggageDimensions:
            false
        default:
            true
        }
    }

    private static func makeQuestion(_ question: QuestionSpec, leg: Leg) -> JourneyConditionQuestion {
        JourneyConditionQuestion(
            spec: question,
            title: TripContentResolver.setupStepTitle(question),
            prompt: TripContentResolver.setupQuestionPrompt(question, leg: leg),
            allowsSkip: false
        )
    }

    private static func facts(
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?,
        hiding currentID: QuestionID?
    ) -> [JourneyConditionFact] {
        var facts: [JourneyConditionFact] = []
        let origin = leg.origin.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let destination = leg.destination.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !origin.isEmpty || !destination.isEmpty {
            facts.append(
                JourneyConditionFact(
                    id: .route,
                    title: LocalizedStringResource(
                        "This journey",
                        comment: "Collapsed confirmation of the origin and destination."
                    ),
                    value: .verbatim("\(origin) → \(destination)"),
                    questionID: nil
                )
            )
        }

        if currentID != .legDate, QuestionEngine.isConfirmed(.legScheduledAt, trip: trip, leg: leg) {
            facts.append(
                JourneyConditionFact(
                    id: .date,
                    title: title(for: .legDate, catalog: catalog),
                    value: dateValue(trip: trip, leg: leg, catalog: catalog),
                    questionID: .legDate
                )
            )
        }
        if currentID != .transport, QuestionEngine.isConfirmed(.legTransportMode, trip: trip, leg: leg) {
            facts.append(
                JourneyConditionFact(
                    id: .transport,
                    title: title(for: .transport, catalog: catalog),
                    value: value(for: .transport, trip: trip, leg: leg, catalog: catalog),
                    questionID: .transport
                )
            )
        }
        if currentID != .ticketStatus, QuestionEngine.isSatisfied(.legReservationStatus, trip: trip, leg: leg) {
            facts.append(
                JourneyConditionFact(
                    id: .booking,
                    title: title(for: .ticketStatus, catalog: catalog),
                    value: QuestionEngine.isConfirmed(.legReservationStatus, trip: trip, leg: leg)
                        ? value(for: .ticketStatus, trip: trip, leg: leg, catalog: catalog)
                        : TripContentResolver.deferredSetupValue(),
                    questionID: .ticketStatus
                )
            )
        }
        if currentID != .luggagePresence,
           continuesPreBooking(leg),
           QuestionEngine.isSatisfied(.legBaggagePresence, trip: trip, leg: leg)
        {
            facts.append(
                JourneyConditionFact(
                    id: .luggage,
                    title: title(for: .luggagePresence, catalog: catalog),
                    value: QuestionEngine.isConfirmed(.legBaggagePresence, trip: trip, leg: leg)
                        ? value(for: .luggagePresence, trip: trip, leg: leg, catalog: catalog)
                        : TripContentResolver.deferredSetupValue(),
                    questionID: .luggagePresence
                )
            )
        }
        return facts
    }

    private static func title(for id: QuestionID, catalog: QuestionCatalog?) -> LocalizedStringResource {
        if let question = catalog?.questions.first(where: { $0.id == id }) {
            return TripContentResolver.setupStepTitle(question)
        }
        return TripContentResolver.setupStepTitle(placeholder(id: id))
    }

    private static func value(
        for id: QuestionID,
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?
    ) -> DisplayText {
        let question = catalog?.questions.first(where: { $0.id == id }) ?? placeholder(id: id)
        return TripContentResolver.setupStepValue(question: question, trip: trip, leg: leg)
    }

    private static func dateValue(trip: Trip, leg: Leg, catalog: QuestionCatalog?) -> DisplayText {
        let dateText = dateText(leg)
        let timeText = timeText(leg)
        switch (dateText, timeText) {
        case (let date?, let time?):
            return .verbatim("\(date) \(time)")
        case (let date?, nil):
            return .verbatim(date)
        case (nil, let time?):
            return .verbatim(time)
        case (nil, nil):
            return value(for: .legDate, trip: trip, leg: leg, catalog: catalog)
        }
    }

    private static func dateText(_ leg: Leg) -> String? {
        guard leg.scheduledAt.status == .confirmed, let date = leg.scheduledAt.value?.date else {
            return nil
        }
        return date.displayString
    }

    private static func timeText(_ leg: Leg) -> String? {
        guard leg.scheduledAt.status == .confirmed,
              let moment = leg.scheduledAt.value,
              !moment.isAllDay,
              let time = moment.time
        else {
            return nil
        }
        return String(format: "%02d:%02d", time.hour, time.minute)
    }

    private static func chapters(
        trip: Trip,
        leg: Leg,
        facts: [JourneyConditionFact],
        current: JourneyConditionQuestion?,
        luggageGuide: TimelineNowItem?
    ) -> [JourneyChapter] {
        let open = openChapter(leg: leg, current: current, luggageGuide: luggageGuide)
        return JourneyChapterID.allCases.map { id in
            let isOpen = id == open
            return JourneyChapter(
                id: id,
                title: title(for: id),
                status: status(for: id, leg: leg, facts: facts),
                isOpen: isOpen,
                question: isOpen ? current : nil,
                luggageGuide: isOpen ? luggageGuide : nil,
                focus: isOpen && id == .reservation ? bookingFocus(leg: leg, current: current, luggageGuide: luggageGuide) : nil,
                reopenQuestionID: reopenQuestionID(for: id, facts: facts)
            )
        }
    }

    private static func openChapter(
        leg: Leg,
        current: JourneyConditionQuestion?,
        luggageGuide: TimelineNowItem?
    ) -> JourneyChapterID {
        if let current {
            switch current.spec.id {
            case .legDate, .transport:
                return .movement
            case .ticketStatus, .luggagePresence:
                return .conditions
            default:
                return .movement
            }
        }
        if luggageGuide != nil {
            return .conditions
        }
        if continuesPreBooking(leg) {
            return .reservation
        }
        if isBooked(leg) {
            return .boarding
        }
        return .conditions
    }

    private static func bookingFocus(
        leg: Leg,
        current: JourneyConditionQuestion?,
        luggageGuide: TimelineNowItem?
    ) -> JourneyChapterFocus? {
        guard current == nil, luggageGuide == nil, continuesPreBooking(leg) else {
            return nil
        }
        let content = TripContentResolver.task(contentKey: ActionPurpose.selectBookingMethod)
        return JourneyChapterFocus(
            title: content.title,
            why: TripContentResolver.taskWhyNow(ActionPurpose.selectBookingMethod)
        )
    }

    private static func sheetItem(in chapters: [JourneyChapter]) -> JourneySheetItem? {
        guard let open = chapters.first(where: \.isOpen) else {
            return nil
        }
        if let question = open.question {
            return JourneySheetItem(
                id: "chapter-\(open.id.rawValue)",
                title: question.title,
                why: question.prompt
            )
        }
        if let guide = open.luggageGuide {
            return JourneySheetItem(
                id: "chapter-luggage",
                title: guide.content.title,
                why: guide.content.subtitle
            )
        }
        if let focus = open.focus {
            return JourneySheetItem(
                id: "chapter-reservation",
                title: focus.title,
                why: focus.why
            )
        }
        return nil
    }

    private static func title(for id: JourneyChapterID) -> LocalizedStringResource {
        switch id {
        case .movement:
            LocalizedStringResource(
                "Journey details",
                comment: "Chapter title for the route, date, and transport of one journey."
            )
        case .conditions:
            LocalizedStringResource(
                "Conditions to confirm",
                comment: "Chapter title for what to confirm before booking."
            )
        case .reservation:
            LocalizedStringResource(
                "Booking chapter",
                comment: "Chapter title for how this journey will be booked."
            )
        case .boarding:
            LocalizedStringResource(
                "Boarding preparation",
                comment: "Chapter title for getting ready to board after booking."
            )
        case .travelDay:
            LocalizedStringResource(
                "Travel day",
                comment: "Chapter title for what happens on the day of travel."
            )
        }
    }

    private static func status(
        for id: JourneyChapterID,
        leg: Leg,
        facts: [JourneyConditionFact]
    ) -> DisplayText {
        switch id {
        case .movement:
            movementStatus(leg: leg)
        case .conditions:
            facts.first { $0.id == .luggage }?.value
                ?? facts.first { $0.id == .booking }?.value
                ?? .localized(LocalizedStringResource(
                    "Not confirmed yet",
                    comment: "Chapter status before booking conditions are known."
                ))
        case .reservation:
            if isBooked(leg), let booking = facts.first(where: { $0.id == .booking }) {
                booking.value
            } else if let booking = facts.first(where: { $0.id == .booking }), !continuesPreBooking(leg) {
                booking.value
            } else {
                .localized(LocalizedStringResource(
                    "After these conditions",
                    comment: "Chapter status before the booking step can open."
                ))
            }
        case .boarding:
            .localized(LocalizedStringResource(
                "After you book",
                comment: "Chapter status for boarding preparation before a ticket path exists."
            ))
        case .travelDay:
            .localized(LocalizedStringResource(
                "On the day",
                comment: "Chapter status for guidance that waits until the travel day."
            ))
        }
    }

    private static func movementStatus(leg: Leg) -> DisplayText {
        var parts: [String] = []
        if let date = dateText(leg) {
            parts.append(date)
        }
        if let time = timeText(leg) {
            parts.append(time)
        }
        if !parts.isEmpty {
            return .verbatim(parts.joined(separator: " · "))
        }
        if leg.transportMode.status == .confirmed, let mode = leg.transportMode.value {
            return .localized(modeTitle(mode))
        }
        return .localized(LocalizedStringResource(
            "Not confirmed yet",
            comment: "Chapter status before booking conditions are known."
        ))
    }

    private static func reopenQuestionID(
        for id: JourneyChapterID,
        facts: [JourneyConditionFact]
    ) -> QuestionID? {
        switch id {
        case .movement:
            if facts.contains(where: { $0.id == .date }) {
                .legDate
            } else if facts.contains(where: { $0.id == .transport }) {
                .transport
            } else {
                nil
            }
        case .conditions:
            if facts.contains(where: { $0.id == .luggage }) {
                .luggagePresence
            } else if facts.contains(where: { $0.id == .booking }) {
                .ticketStatus
            } else {
                nil
            }
        case .reservation, .boarding, .travelDay:
            nil
        }
    }

    private static func modeTitle(_ leg: Leg) -> LocalizedStringResource {
        if leg.transportMode.status == .confirmed, let mode = leg.transportMode.value {
            return modeTitle(mode)
        }
        return LocalizedStringResource(
            "This ride",
            comment: "Detail heading before the transport mode is known."
        )
    }

    private static func modeTitle(_ mode: TransportMode) -> LocalizedStringResource {
        switch mode {
        case .shinkansen:
            LocalizedStringResource("Shinkansen", comment: "Confirmed Shinkansen transport label on a leg row.")
        case .airplane:
            LocalizedStringResource("Flight", comment: "Confirmed airplane transport label on a leg row.")
        case .localTrain:
            LocalizedStringResource("Local train", comment: "Confirmed local-train transport label on a leg row.")
        case .bus:
            LocalizedStringResource("Bus", comment: "Confirmed bus transport label on a leg row.")
        case .taxi:
            LocalizedStringResource("Taxi", comment: "Confirmed taxi transport label on a leg row.")
        case .walking:
            LocalizedStringResource("Walk", comment: "Confirmed walking transport label on a leg row.")
        case .car:
            LocalizedStringResource("Car", comment: "Confirmed car transport label on a leg row.")
        case .ferry:
            LocalizedStringResource("Ferry", comment: "Confirmed ferry transport label on a leg row.")
        case .other:
            LocalizedStringResource("Other transport", comment: "Confirmed other-transport label on a leg row.")
        }
    }

    private static func metaText(_ leg: Leg) -> String? {
        var parts: [String] = []
        if let date = dateText(leg) {
            parts.append(date)
        }
        if let time = timeText(leg) {
            parts.append(time)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func luggageGuide(
        trip: Trip,
        leg: Leg,
        hidingQuestion: Bool
    ) -> TimelineNowItem? {
        guard !hidingQuestion, continuesPreBooking(leg) else {
            return nil
        }
        guard let task = trip.tasks.first(where: { task in
            guard task.contentKey == ActionPurpose.captureDimensions,
                  task.relatedGuideID == .shinkansenBaggageMeasurement,
                  task.state != .completed,
                  task.state != .cancelled
            else {
                return false
            }
            if case .leg(let id) = task.scope {
                return id == leg.id
            }
            return false
        }) else {
            return nil
        }
        let item = TimelineNowItem(
            id: .task(task.id),
            kind: .task(task.id),
            contentKey: task.contentKey,
            content: TripContentResolver.task(contentKey: task.contentKey),
            destination: .taskDetail(trip.id, task.id)
        )
        return HomePrimaryActionComposer.routed(item, trip: trip)
    }

    private static func placeholder(id: QuestionID) -> QuestionSpec {
        QuestionSpec(
            id: id,
            priority: 0,
            target: target(for: id),
            uiKind: .singleChoice,
            answerType: target(for: id).expectedAnswerType,
            when: .always,
            choices: [],
            role: .setup
        )
    }

    private static func target(for id: QuestionID) -> QuestionTarget {
        switch id {
        case .legDate:
            .legScheduledAt
        case .transport:
            .legTransportMode
        case .ticketStatus:
            .legReservationStatus
        case .selectService:
            .legReservationService
        case .luggagePresence:
            .legBaggagePresence
        case .baggageDimensions:
            .bagDimensions
        default:
            .legScheduledAt
        }
    }
}
