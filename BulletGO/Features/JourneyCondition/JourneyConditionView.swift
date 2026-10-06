import SwiftUI

struct JourneyConditionView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tripID: TripID
    let legID: LegID

    @State private var selectedDate = Date()
    @State private var reopenedQuestionID: QuestionID?
    @State private var isAnswering = false
    @State private var stepError = false

    private let timeZone = TripCalendar.timeZone

    var body: some View {
        Group {
            if let trip, let leg {
                content(trip: trip, leg: leg)
            } else {
                ContentUnavailableView("This journey isn’t available", systemImage: "map")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidedAddPalette.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legDetail)
        .onAppear {
            if let start = trip?.startDate.value?.date(in: timeZone) {
                selectedDate = start
            }
        }
    }

    private var trip: Trip? {
        guard let trip = session.trip, trip.id == tripID else { return nil }
        return trip
    }

    private var leg: Leg? {
        trip?.legs.first { $0.id == legID }
    }

    private func content(trip: Trip, leg: Leg) -> some View {
        let snapshot = JourneyConditionComposer.snapshot(
            trip: trip,
            leg: leg,
            catalog: session.catalog,
            reopenedQuestionID: reopenedQuestionID
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                JourneyConditionHeader(snapshot: snapshot)
                if let cockpit = snapshot.cockpit {
                    JourneyCockpitCard(
                        cockpit: cockpit,
                        isBusy: isAnswering,
                        hasError: stepError,
                        onStateBoarding: { means in
                            Task { await stateBoarding(means) }
                        }
                    )
                }
                ForEach(snapshot.chapters) { chapter in
                    JourneyChapterCard(
                        chapter: chapter,
                        selectedDate: $selectedDate,
                        isBusy: isAnswering,
                        hasError: stepError,
                        onReopen: { questionID in
                            reopenedQuestionID = questionID
                            stepError = false
                        },
                        onConfirmDate: { question in
                            Task { await confirmDate(for: question) }
                        },
                        onChoice: { value, question in
                            Task { await confirmChoice(value, for: question) }
                        },
                        onSkip: { question in
                            Task { await skip(question) }
                        },
                        onOpenLuggage: { item in
                            openLuggageGuide(item, trip: trip)
                        },
                        onOpenFocus: { link in
                            switch link {
                            case .bookingMethods:
                                router.push(.bookingMethods(trip.id, leg.id))
                            case .bookingRecord:
                                router.push(.bookingRecord(trip.id, leg.id))
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(GuidedAddMotion.card(reduceMotion), value: snapshot.chapters.map(\.isOpen))
            .animation(GuidedAddMotion.card(reduceMotion), value: snapshot.current?.spec.id)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            snapshot.current == nil
                ? AccessibilityID.journeyConditions
                : AccessibilityID.legSetup
        )
    }

    private func openLuggageGuide(_ item: TimelineNowItem, trip: Trip) {
        if let destination = HomePrimaryActionComposer.destination(for: item, trip: trip) {
            router.push(destination)
        }
    }

    private func confirmDate(for question: QuestionSpec) async {
        do {
            let local = try LocalDate(date: selectedDate, timeZone: timeZone)
            let moment = try ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier)
            await answer(question, .scheduledMoment(moment))
        } catch {
            stepError = true
        }
    }

    private func confirmChoice(_ value: String, for question: QuestionSpec) async {
        await answer(question, .choice(value))
    }

    private func skip(_ question: QuestionSpec) async {
        switch question.id {
        case .ticketStatus:
            await answer(question, .choice("unsure"))
        case .luggagePresence:
            await answer(question, .choice("skip"))
        default:
            break
        }
    }

    private func answer(_ question: QuestionSpec, _ answer: QuestionAnswer) async {
        isAnswering = true
        defer { isAnswering = false }
        if session.trip?.focusLegID != legID {
            _ = await session.process(.focusLeg(legID))
        }
        guard await session.process(.answerQuestion(question.id, answer)) != nil else {
            stepError = true
            return
        }
        reopenedQuestionID = nil
        stepError = false
    }

    private func stateBoarding(_ means: StatedBoardingMeans?) async {
        isAnswering = true
        defer { isAnswering = false }
        guard await session.process(.applyMutation(.setStatedBoarding(legID, means))) != nil else {
            stepError = true
            return
        }
        stepError = false
    }
}

private struct JourneyConditionHeader: View {
    var snapshot: JourneyConditionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.modeTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(GuidedAddPalette.primaryText)
            Text(verbatim: snapshot.title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(GuidedAddPalette.primaryText)
            if let metaText = snapshot.metaText {
                Text(verbatim: metaText)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
            }
            if let cockpit = snapshot.cockpit {
                Text(verbatim: cockpit.rideSummary)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                Text(cockpit.bookingLine)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct JourneyCockpitCard: View {
    var cockpit: JourneyCockpit
    var isBusy: Bool
    var hasError: Bool
    var onStateBoarding: (StatedBoardingMeans?) -> Void

    @State private var showsBoardingChoices = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to do now")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
            if cockpit.canRestateBoarding {
                if let guidance = cockpit.statedGuidance {
                    Text(guidance)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Choose again") {
                    showsBoardingChoices = false
                    onStateBoarding(nil)
                }
                .buttonStyle(.plain)
                .font(DesignTokens.Typography.footnote)
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .disabled(isBusy)
                .accessibilityIdentifier(AccessibilityID.journeyBoardingChange)
                boardingNotes
            } else if showsBoardingChoices {
                Text("On the reservation screen, which one is shown for the gate?")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(cockpit.boardingChoices) { means in
                    Button {
                        onStateBoarding(means)
                    } label: {
                        Text(means.choiceTitle)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(GuidedAddPalette.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, 16)
                            .background(
                                GuidedAddPalette.mutedFill,
                                in: RoundedRectangle(cornerRadius: GuidedAddMetrics.howRadius, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                    .accessibilityIdentifier(AccessibilityID.boardingChoice(means.rawValue))
                }
                Button("Not sure yet") {
                    showsBoardingChoices = false
                }
                .buttonStyle(.plain)
                .font(DesignTokens.Typography.footnote)
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .disabled(isBusy)
                .accessibilityIdentifier(AccessibilityID.journeyBoardingUnknown)
                boardingNotes
            } else {
                Text("Check how you'll pass the gate")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                VStack(alignment: .leading, spacing: 8) {
                    Text("The booking is recorded. How you pass the gate is separate.")
                    Text("You can leave it only after you look at the reservation screen.")
                }
                .font(DesignTokens.Typography.body)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.journeyBoardingBridge)
                Button("Leave it from the reservation screen") {
                    showsBoardingChoices = true
                }
                .buttonStyle(.plain)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                .disabled(isBusy)
                .accessibilityIdentifier(AccessibilityID.journeyBoardingEntrance)
                boardingNotes
            }
            if hasError {
                Text("Couldn’t save that. Try this step again.")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GuidedAddPalette.card,
            in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.journeyCockpit)
    }

    @ViewBuilder
    private var boardingNotes: some View {
        if !cockpit.notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(cockpit.notes.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityIdentifier(AccessibilityID.journeyBoardingGuidance)
        }
    }
}

private struct JourneyChapterCard: View {
    var chapter: JourneyChapter
    @Binding var selectedDate: Date
    var isBusy: Bool
    var hasError: Bool
    var onReopen: (QuestionID) -> Void
    var onConfirmDate: (QuestionSpec) -> Void
    var onChoice: (String, QuestionSpec) -> Void
    var onSkip: (QuestionSpec) -> Void
    var onOpenLuggage: (TimelineNowItem) -> Void
    var onOpenFocus: (JourneyChapterLink) -> Void

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Text(verbatim: "\(chapter.id.number)")
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                    DisplayTextLabel(text: chapter.status)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(GuidedAddPalette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if chapter.isOpen {
                openBody
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GuidedAddPalette.card,
            in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)

        if let questionID = chapter.reopenQuestionID, !chapter.isOpen {
            Button {
                onReopen(questionID)
            } label: {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    @ViewBuilder
    private var openBody: some View {
        if let question = chapter.question {
            JourneyConditionOpenCard(
                question: question,
                selectedDate: $selectedDate,
                isBusy: isBusy,
                hasError: hasError,
                onConfirmDate: { onConfirmDate(question.spec) },
                onChoice: { onChoice($0, question.spec) },
                onSkip: question.allowsSkip ? { onSkip(question.spec) } : nil
            )
        } else if let item = chapter.luggageGuide {
            JourneyConditionLuggageCard(item: item) {
                onOpenLuggage(item)
            }
        } else if let focus = chapter.focus {
            Button {
                onOpenFocus(focus.link)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(focus.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(GuidedAddPalette.primaryText)
                        Text(focus.why)
                            .font(DesignTokens.Typography.footnote)
                            .foregroundStyle(GuidedAddPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text("›")
                        .font(.system(size: 22))
                        .foregroundStyle(GuidedAddPalette.secondaryText)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GuidedAddPalette.mutedFill,
                    in: RoundedRectangle(cornerRadius: GuidedAddMetrics.howRadius, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                focus.link == .bookingRecord
                    ? AccessibilityID.bookingRecordOpen
                    : AccessibilityID.journeyChapterFocus
            )
        }
    }

    private var accessibilityID: String {
        if chapter.id == .movement {
            return AccessibilityID.journeyConditionRoute
        }
        return AccessibilityID.journeyChapter(chapter.id.rawValue)
    }
}

private struct JourneyConditionOpenCard: View {
    var question: JourneyConditionQuestion
    @Binding var selectedDate: Date
    var isBusy: Bool
    var hasError: Bool
    var onConfirmDate: () -> Void
    var onChoice: (String) -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question.prompt)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.legSetup)

            JourneyConditionAnswerView(
                question: question.spec,
                selectedDate: $selectedDate,
                isBusy: isBusy,
                onConfirmDate: onConfirmDate,
                onChoice: onChoice,
                onSkip: onSkip
            )

            if hasError {
                Text("Couldn’t save that. Try this step again.")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legSetupCurrent)
    }
}

private struct JourneyConditionAnswerView: View {
    var question: QuestionSpec
    @Binding var selectedDate: Date
    var isBusy: Bool
    var onConfirmDate: () -> Void
    var onChoice: (String) -> Void
    var onSkip: (() -> Void)?

    @State private var displayedMonth: Date

    init(
        question: QuestionSpec,
        selectedDate: Binding<Date>,
        isBusy: Bool,
        onConfirmDate: @escaping () -> Void,
        onChoice: @escaping (String) -> Void,
        onSkip: (() -> Void)?
    ) {
        self.question = question
        _selectedDate = selectedDate
        self.isBusy = isBusy
        self.onConfirmDate = onConfirmDate
        self.onChoice = onChoice
        self.onSkip = onSkip
        _displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch question.uiKind {
            case .dateTime:
                GuidedAddCard {
                    VStack(alignment: .leading, spacing: 16) {
                        GuidedAddDateGrid(
                            month: displayedMonth,
                            selected: selectedDate,
                            onSelect: { date in
                                selectedDate = date
                                displayedMonth = date
                            },
                            onChangeMonth: { delta in
                                displayedMonth = GuidedAddCopy.tokyoCalendar.date(
                                    byAdding: .month,
                                    value: delta,
                                    to: displayedMonth
                                ) ?? displayedMonth
                            }
                        )
                        PrimaryCTA(
                            title: LocalizedStringResource(
                                "Use this date",
                                comment: "Primary action confirming the suggested travel date."
                            ),
                            isBusy: isBusy,
                            accessibilityID: AccessibilityID.dateConfirm,
                            action: onConfirmDate
                        )
                    }
                    .padding(18)
                }
                .onChange(of: selectedDate) { _, date in
                    displayedMonth = date
                }
            case .singleChoice:
                VStack(spacing: 8) {
                    ForEach(question.choices, id: \.value) { choice in
                        JourneyConditionChoiceRow(
                            title: TripContentResolver.questionChoiceTitle(choice),
                            transportValue: question.id == .transport ? choice.value : nil,
                            isBusy: isBusy
                        ) {
                            onChoice(choice.value)
                        }
                        .accessibilityIdentifier(AccessibilityID.questionChoice(choice.value))
                    }
                }
            case .dimensions:
                EmptyView()
            }

            if let onSkip {
                Button(action: onSkip) {
                    HStack {
                        Text("I’ll answer later")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(GuidedAddPalette.primaryText)
                        Spacer()
                        Text("→")
                            .font(.system(size: 21, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum)
                }
                .disabled(isBusy)
                .accessibilityIdentifier(AccessibilityID.questionSkip(question.id))
            }
        }
    }
}

private struct JourneyConditionChoiceRow: View {
    var title: LocalizedStringResource
    var transportValue: String?
    var isBusy: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(Font.title3.weight(.semibold))
                        .foregroundStyle(GuidedAddPalette.primaryText)
                        .padding(.leading, 8)
                    if let mode {
                        HStack {
                            transportIcon(mode)
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 7)
                Text("›")
                    .font(.system(size: 22))
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: GuidedAddMetrics.howHeight, alignment: .leading)
            .background(
                GuidedAddPalette.mutedFill,
                in: RoundedRectangle(cornerRadius: GuidedAddMetrics.howRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private var mode: TransportMode? {
        guard let transportValue else {
            return nil
        }
        return TransportMode(rawValue: transportValue)
    }

    @ViewBuilder
    private func transportIcon(_ mode: TransportMode) -> some View {
        if let name = TravelGuidedAdd.modeImage(mode) {
            Image(name)
                .renderingMode(.template)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .accessibilityHidden(true)
        } else {
            Image(systemName: TravelGuidedAdd.modeSymbol(mode))
                .font(DesignTokens.Typography.title)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .frame(width: GuidedAddMetrics.transportIcon.width, height: GuidedAddMetrics.transportIcon.height)
                .accessibilityHidden(true)
        }
    }
}

private struct JourneyConditionLuggageCard: View {
    var item: TimelineNowItem
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.content.title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = item.content.subtitle {
                Text(subtitle)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryCTA(
                title: TripContentResolver.taskPrimaryAction(item.contentKey),
                accessibilityID: AccessibilityID.journeyConditionLuggage,
                action: action
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.nowTask(contentKey: item.contentKey))
    }
}

#if DEBUG
#Preview("Conditions") {
    NavigationStack {
        JourneyConditionView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Conditions Japanese") {
    NavigationStack {
        JourneyConditionView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Ready for luggage") {
    NavigationStack {
        JourneyConditionView(tripID: PreviewTrips.readyForNow.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
}

#Preview("Booked") {
    NavigationStack {
        JourneyConditionView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.setupPaused))
}
#endif
