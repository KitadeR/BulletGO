import SwiftUI

struct LegDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let legID: LegID
    @State private var origin = ""
    @State private var destination = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var confirmDateChange = false
    @State private var pendingDate: Date?
    @State private var didLoadFields = false
    @State private var selectedDate = Date()
    @State private var reopenedQuestionID: QuestionID?
    @State private var isAnswering = false
    @State private var stepError = false

    private let timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt

    var body: some View {
        Group {
            if let trip, let leg {
                detail(trip: trip, leg: leg)
            } else {
                ContentUnavailableView("This journey isn’t available", systemImage: "map")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ChromeIconButton(
                    systemImage: "chevron.backward",
                    accessibilityLabel: LocalizedStringResource("Back", comment: "Back button on journey detail."),
                    action: { dismiss() }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legDetail)
        .onAppear {
            loadLegFields()
            if let start = trip?.startDate.value?.date(in: timeZone) {
                selectedDate = start
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                didLoadFields = true
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

    private func detail(trip: Trip, leg: Leg) -> some View {
        let snapshot = LegDetailComposer.snapshot(trip: trip, leg: leg, catalog: session.catalog)
        let remembered = TimelineNextComposer.rememberedItems(for: trip, legID: leg.id)
        return ZStack(alignment: .top) {
            DesignTokens.Color.canvas
                .ignoresSafeArea()
            JourneyArtwork(kind: JourneyVisualProvider.kind(for: leg))
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 112)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        Text(verbatim: snapshot.title)
                            .font(DesignTokens.Typography.display)
                            .fixedSize(horizontal: false, vertical: true)

                        switch snapshot.mode {
                        case .setup:
                            if let setup = snapshot.setup {
                                setupSection(setup)
                            }
                        case .cockpit:
                            if let cockpit = snapshot.cockpit {
                                LegCockpitContentView(cockpit: cockpit) { item in
                                    handleWhatsNext(item, trip: trip)
                                }
                            }
                        }

                        secondaryTalkButton(mode: snapshot.mode)

                        if !remembered.isEmpty {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                Text("Remembered")
                                    .font(DesignTokens.Typography.headline)
                                    .accessibilityIdentifier(AccessibilityID.rememberedSection)
                                ForEach(remembered) { item in
                                    QuietComingUpRow(
                                        title: .localized(item.content.title),
                                        subtitle: item.content.subtitle.map(DisplayText.localized),
                                        systemImage: item.content.systemImage,
                                        showsChevron: false,
                                        accessibilityID: AccessibilityID.rememberedRow(rememberedContentKey(item))
                                    )
                                }
                            }
                        }

                        editSection(leg: leg)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        DesignTokens.Color.canvas,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: DesignTokens.Radius.hero,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: DesignTokens.Radius.hero,
                            style: .continuous
                        )
                    )
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setupSection(_ setup: LegSetupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(setup.steps) { step in
                let expanded = isExpanded(step)
                LegSetupStepView(
                    step: step,
                    isExpanded: expanded,
                    selectedDate: $selectedDate,
                    isBusy: isAnswering,
                    hasError: expanded && stepError,
                    onConfirmDate: { Task { await confirmDate(for: step.question) } },
                    onChoice: { value in Task { await confirmChoice(value, for: step.question) } },
                    onSkip: canSkip(step.question) ? { Task { await skip(step.question) } } : nil,
                    onReopen: step.kind == .deferred ? { reopenedQuestionID = step.question.id } : nil
                )
            }
            if setup.isPaused {
                Text("You can confirm this later when it’s needed.")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.legSetupPaused)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legSetup)
    }

    private func isExpanded(_ step: LegSetupStep) -> Bool {
        if reopenedQuestionID == step.question.id {
            return true
        }
        return step.kind == .current && reopenedQuestionID == nil
    }

    private func canSkip(_ question: QuestionSpec) -> Bool {
        question.id == .ticketStatus || question.id == .luggagePresence
    }

    private func secondaryTalkButton(mode: LegDetailMode) -> some View {
        Button {
            router.present(.guidance(tripID, legID, .compose, .stayInPlace))
        } label: {
            Label {
                Text(
                    mode == .setup
                        ? LocalizedStringResource(
                            "Tell us in your own words",
                            comment: "Secondary free-text action on journey setup."
                        )
                        : LocalizedStringResource(
                            "Add more about this journey",
                            comment: "Secondary free-text action on the journey cockpit."
                        )
                )
            } icon: {
                Image(systemName: "text.bubble")
            }
            .font(DesignTokens.Typography.body)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(AccessibilityID.startGuidance)
    }

    private func handleWhatsNext(_ item: TimelineNowItem, trip: Trip) {
        switch item.kind {
        case .task:
            if let destination = HomePrimaryActionComposer.destination(for: item, trip: trip) {
                router.push(destination)
            }
        case .resume(let id):
            router.present(.guidance(tripID, id, .compose, .stayInPlace))
        }
    }

    private func editSection(leg: Leg) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                TextField("From", text: $origin)
                    .textFieldStyle(.roundedBorder)
                TextField("To", text: $destination)
                    .textFieldStyle(.roundedBorder)
                Toggle("Has a date", isOn: $hasDate)
                if hasDate {
                    DatePicker("Travel date", selection: $date, displayedComponents: .date)
                }
                Button("Move to Unscheduled") {
                    Task { _ = await session.process(.applyMutation(.unscheduleLeg(legID))) }
                }
                .disabled(leg.scheduledAt.status != .confirmed)
                Button("Delete journey", role: .destructive) {
                    Task {
                        _ = await session.process(.applyMutation(.removeLeg(legID)))
                        dismiss()
                    }
                }
            }
            .padding(.top, DesignTokens.Spacing.sm)
        } label: {
            Text("Edit this journey")
                .font(DesignTokens.Typography.headline)
        }
        .onChange(of: origin) { _, newValue in
            guard didLoadFields else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != leg.origin.value else { return }
            Task { _ = await session.process(.applyMutation(.updateLegOrigin(legID, trimmed))) }
        }
        .onChange(of: destination) { _, newValue in
            guard didLoadFields else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != leg.destination.value else { return }
            Task { _ = await session.process(.applyMutation(.updateLegDestination(legID, trimmed))) }
        }
        .onChange(of: hasDate) { _, newValue in
            guard didLoadFields else { return }
            if !newValue {
                Task { _ = await session.process(.applyMutation(.unscheduleLeg(legID))) }
            }
        }
        .onChange(of: date) { _, newValue in
            guard didLoadFields, hasDate else { return }
            if leg.scheduledAt.status == .confirmed {
                pendingDate = newValue
                confirmDateChange = true
            } else {
                Task { await saveDate(newValue) }
            }
        }
        .alert("Change this journey’s date?", isPresented: $confirmDateChange) {
            Button("Change") {
                if let pendingDate {
                    Task { await saveDate(pendingDate) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDate = nil }
        } message: {
            Text("Dragging does not change times. This updates the travel date.")
        }
    }

    private func loadLegFields() {
        origin = leg?.origin.value ?? ""
        destination = leg?.destination.value ?? ""
        if let scheduled = leg?.scheduledAt.value,
           let dateValue = scheduled.date.date(in: TimeZone(identifier: scheduled.timeZoneIdentifier) ?? .current) {
            hasDate = true
            date = dateValue
        } else {
            hasDate = false
        }
    }

    private func saveDate(_ value: Date) async {
        let zone = TimeZone.current
        guard let local = try? LocalDate(date: value, timeZone: zone),
              let moment = try? ScheduledMoment(date: local, timeZoneIdentifier: zone.identifier) else {
            return
        }
        _ = await session.process(.applyMutation(.setLegScheduledAt(legID, moment)))
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

    private func rememberedContentKey(_ item: TimelineNextItem) -> String {
        if case .remembered(let remembered) = item.kind {
            return remembered.contentKey
        }
        return ""
    }
}

#if DEBUG
#Preview("Setup") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Setup Japanese") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Deferred") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.setupPaused.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.setupPaused))
}

#Preview("Airplane") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.airplaneSetup.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.airplaneSetup))
}

#Preview("Cockpit") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
}

#Preview("Cockpit Japanese") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Remembered") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.withComingUpAndRemembered.id,
            legID: PreviewTrips.withComingUpAndRemembered.legs[0].id
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
}

#Preview("Dark") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .dynamicTypeSize(.accessibility3)
}
#endif
