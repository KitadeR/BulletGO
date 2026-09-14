import SwiftUI

struct GuidedAddFlowView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var model: GuidedAddFlowModel
    @State private var search: (any PlaceSearching)?

    init(
        tripID: TripID,
        kind: ItineraryAddKind,
        initialDate: LocalDate?,
        now: Date,
        search: (any PlaceSearching)? = nil,
        seedPlace: PlaceReference? = nil
    ) {
        _model = State(initialValue: GuidedAddFlowModel(
            tripID: tripID,
            kind: kind,
            initialDate: initialDate,
            now: now,
            seedPlace: seedPlace
        ))
        _search = State(initialValue: search)
    }

    var body: some View {
        NavigationStack {
            stepContent
                .navigationTitle(Text(model.currentStep.title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if model.isFirstStep {
                            Button("Cancel") { attemptDismiss() }
                                .accessibilityIdentifier(AccessibilityID.guidedAddCancel)
                        } else {
                            Button("Back") { model.back() }
                                .accessibilityIdentifier(AccessibilityID.guidedAddBack)
                        }
                    }
                    if model.isReview {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") { Task { await save() } }
                                .disabled(!model.canAdvance || model.isSaving)
                                .accessibilityIdentifier(AccessibilityID.guidedAddSave)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if !model.isReview {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            if canSkip {
                                Button("Later") { model.skipOptional() }
                                    .accessibilityIdentifier(AccessibilityID.guidedAddSkip)
                            }
                            PrimaryCTA(
                                title: "Continue",
                                isEnabled: model.canAdvance,
                                isBusy: model.isSaving,
                                accessibilityID: AccessibilityID.guidedAddContinue,
                                action: { model.advance() }
                            )
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                }
        }
        .interactiveDismissDisabled(model.isDirty)
        .onChange(of: model.isDirty) { _, _ in }
        .confirmationDialog(
            "Discard this item?",
            isPresented: $model.showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { router.dismissPresentation() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Couldn’t add this item", isPresented: $model.saveFailed) {
            Button("OK", role: .cancel) {}
        }
        .accessibilityIdentifier(AccessibilityID.guidedAddSheet)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.draft {
        case .activity(let draft):
            activityStep(draft)
        case .travel(let draft):
            travelStep(draft)
        case .stay(let draft):
            stayStep(draft)
        }
    }

    @ViewBuilder
    private func activityStep(_ draft: ActivityAddDraft) -> some View {
        Form {
            switch model.currentStep {
            case .activityWhat:
                TextField("What are you doing?", text: activityTitle)
                    .accessibilityIdentifier(AccessibilityID.guidedAddTitle)
                PlaceSearchField(
                    title: "Where?",
                    text: activityPlace,
                    search: search,
                    onSelect: { reference in
                        updateActivity { $0.placeReference = reference; $0.place = reference.name }
                    },
                    onClear: { updateActivity { $0.placeReference = nil } }
                )
            case .activityDate:
                Toggle("Add to a day", isOn: activityHasDate)
                if draft.hasDate {
                    DatePicker("Date", selection: activityDate, displayedComponents: .date)
                }
            case .activityTiming:
                Picker("Time", selection: activityTiming) {
                    ForEach(ActivityTimingChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .pickerStyle(.inline)
                if draft.timing == .start || draft.timing == .range {
                    DatePicker("Starts", selection: activityStart, displayedComponents: .hourAndMinute)
                }
                if draft.timing == .range {
                    DatePicker("Ends", selection: activityEnd, displayedComponents: .hourAndMinute)
                }
            case .activityReview:
                reviewRow("What", trimmed(draft.title).isEmpty ? trimmed(draft.place) : trimmed(draft.title))
                if !trimmed(draft.place).isEmpty {
                    reviewRow("Where", trimmed(draft.place))
                }
                reviewRow("When", activityWhenText(draft))
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func travelStep(_ draft: LegAddDraft) -> some View {
        Form {
            switch model.currentStep {
            case .travelOrigin:
                PlaceSearchField(
                    title: "From",
                    text: travelOrigin,
                    search: search,
                    accessibilityID: AccessibilityID.guidedAddOrigin,
                    onSelect: { reference in
                        updateTravel { $0.originPlace = reference; $0.origin = reference.name }
                    },
                    onClear: { updateTravel { $0.originPlace = nil } }
                )
            case .travelDestination:
                PlaceSearchField(
                    title: "To",
                    text: travelDestination,
                    search: search,
                    accessibilityID: AccessibilityID.guidedAddDestination,
                    onSelect: { reference in
                        updateTravel { $0.destinationPlace = reference; $0.destination = reference.name }
                    },
                    onClear: { updateTravel { $0.destinationPlace = nil } }
                )
            case .travelMode:
                Picker("Transport", selection: travelMode) {
                    Text("Decide later").tag(Optional<TransportMode>.none)
                    ForEach(Self.modes, id: \.self) { mode in
                        Text(modeLabel(mode)).tag(Optional(mode))
                    }
                }
                .pickerStyle(.inline)
            case .travelSchedule:
                Toggle("Has a date", isOn: travelHasDate)
                if draft.hasDate {
                    DatePicker("Date", selection: travelDate, displayedComponents: .date)
                    Toggle("Departure time", isOn: travelHasDeparture)
                    if draft.hasDepartureTime {
                        DatePicker("Departs", selection: travelDeparture, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Arrival time", isOn: travelHasArrival)
                    if draft.hasArrivalTime {
                        DatePicker("Arrives", selection: travelArrival, displayedComponents: .hourAndMinute)
                    }
                }
            case .travelReview:
                reviewRow("From", trimmed(draft.origin))
                reviewRow("To", trimmed(draft.destination))
                reviewRow("How", draft.mode.map(modeLabel) ?? String(localized: "Later"))
                reviewRow("When", travelWhenText(draft))
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func stayStep(_ draft: StayAddDraft) -> some View {
        Form {
            switch model.currentStep {
            case .stayPlace:
                PlaceSearchField(
                    title: "Where are you staying?",
                    text: stayPlace,
                    search: search,
                    onSelect: { reference in
                        updateStay { $0.placeReference = reference; $0.place = reference.name }
                    },
                    onClear: { updateStay { $0.placeReference = nil } }
                )
            case .stayCheckIn:
                Toggle("Check-in date known", isOn: stayHasCheckIn)
                if draft.hasCheckIn {
                    DatePicker("Check-in", selection: stayCheckIn, displayedComponents: .date)
                }
            case .stayCheckOut:
                Toggle("Check-out date known", isOn: stayHasCheckOut)
                if draft.hasCheckOut {
                    DatePicker("Check-out", selection: stayCheckOut, displayedComponents: .date)
                }
            case .stayReview:
                reviewRow("Stay", trimmed(draft.place))
                reviewRow("Check-in", draft.hasCheckIn ? formatted(draft.checkIn) : String(localized: "Later"))
                reviewRow("Check-out", draft.hasCheckOut ? formatted(draft.checkOut) : String(localized: "Later"))
            default:
                EmptyView()
            }
        }
    }

    private var canSkip: Bool {
        switch model.currentStep {
        case .travelMode, .activityTiming, .stayCheckIn, .stayCheckOut: true
        default: false
        }
    }

    private func reviewRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(title) {
            Text(verbatim: value)
        }
    }

    private func attemptDismiss() {
        if model.isDirty {
            model.showDiscardConfirmation = true
        } else {
            router.dismissPresentation()
        }
    }

    private func save() async {
        if await model.commit(session: session) {
            router.dismissPresentation()
        }
    }

    private static let modes: [TransportMode] = [
        .shinkansen, .airplane, .localTrain, .bus, .taxi, .walking, .car, .ferry, .other,
    ]

    private func modeLabel(_ mode: TransportMode) -> String {
        switch mode {
        case .shinkansen: String(localized: "Shinkansen")
        case .airplane: String(localized: "Flight")
        case .localTrain: String(localized: "Local train")
        case .bus: String(localized: "Bus")
        case .taxi: String(localized: "Taxi")
        case .walking: String(localized: "Walk")
        case .car: String(localized: "Car")
        case .ferry: String(localized: "Ferry")
        case .other: String(localized: "Other")
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func activityWhenText(_ draft: ActivityAddDraft) -> String {
        guard draft.hasDate else { return String(localized: "Unscheduled") }
        switch draft.timing {
        case .none: return formatted(draft.date)
        case .allDay: return "\(formatted(draft.date)) · \(String(localized: "All day"))"
        case .start: return draft.startTime.formatted(date: .abbreviated, time: .shortened)
        case .range:
            return "\(draft.startTime.formatted(date: .abbreviated, time: .shortened)) – \(draft.endTime.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func travelWhenText(_ draft: LegAddDraft) -> String {
        guard draft.hasDate else { return String(localized: "Unscheduled") }
        if draft.hasDepartureTime {
            return draft.departureTime.formatted(date: .abbreviated, time: .shortened)
        }
        return formatted(draft.date)
    }
}

private extension GuidedAddFlowView {
    var activityDraft: ActivityAddDraft {
        if case .activity(let value) = model.draft { return value }
        return ActivityAddDraft()
    }

    var travelDraft: LegAddDraft {
        if case .travel(let value) = model.draft { return value }
        return LegAddDraft()
    }

    var stayDraft: StayAddDraft {
        if case .stay(let value) = model.draft { return value }
        return StayAddDraft()
    }

    func updateActivity(_ body: (inout ActivityAddDraft) -> Void) {
        guard case .activity(var value) = model.draft else { return }
        body(&value)
        model.draft = .activity(value)
    }

    func updateTravel(_ body: (inout LegAddDraft) -> Void) {
        guard case .travel(var value) = model.draft else { return }
        body(&value)
        model.draft = .travel(value)
    }

    func updateStay(_ body: (inout StayAddDraft) -> Void) {
        guard case .stay(var value) = model.draft else { return }
        body(&value)
        model.draft = .stay(value)
    }

    var activityTitle: Binding<String> {
        Binding(get: { activityDraft.title }, set: { newValue in updateActivity { $0.title = newValue } })
    }

    var activityPlace: Binding<String> {
        Binding(get: { activityDraft.place }, set: { newValue in updateActivity { $0.place = newValue } })
    }

    var activityHasDate: Binding<Bool> {
        Binding(get: { activityDraft.hasDate }, set: { newValue in updateActivity { $0.hasDate = newValue } })
    }

    var activityDate: Binding<Date> {
        Binding(get: { activityDraft.date }, set: { newValue in updateActivity { $0.date = newValue } })
    }

    var activityTiming: Binding<ActivityTimingChoice> {
        Binding(get: { activityDraft.timing }, set: { newValue in updateActivity { $0.timing = newValue } })
    }

    var activityStart: Binding<Date> {
        Binding(get: { activityDraft.startTime }, set: { newValue in updateActivity { $0.startTime = newValue } })
    }

    var activityEnd: Binding<Date> {
        Binding(get: { activityDraft.endTime }, set: { newValue in updateActivity { $0.endTime = newValue } })
    }

    var travelOrigin: Binding<String> {
        Binding(get: { travelDraft.origin }, set: { newValue in updateTravel { $0.origin = newValue } })
    }

    var travelDestination: Binding<String> {
        Binding(get: { travelDraft.destination }, set: { newValue in updateTravel { $0.destination = newValue } })
    }

    var travelMode: Binding<TransportMode?> {
        Binding(get: { travelDraft.mode }, set: { newValue in updateTravel { $0.mode = newValue; $0.skipMode = newValue == nil } })
    }

    var travelHasDate: Binding<Bool> {
        Binding(get: { travelDraft.hasDate }, set: { newValue in updateTravel { $0.hasDate = newValue } })
    }

    var travelDate: Binding<Date> {
        Binding(get: { travelDraft.date }, set: { newValue in updateTravel { $0.date = newValue } })
    }

    var travelHasDeparture: Binding<Bool> {
        Binding(get: { travelDraft.hasDepartureTime }, set: { newValue in updateTravel { $0.hasDepartureTime = newValue } })
    }

    var travelDeparture: Binding<Date> {
        Binding(get: { travelDraft.departureTime }, set: { newValue in updateTravel { $0.departureTime = newValue } })
    }

    var travelHasArrival: Binding<Bool> {
        Binding(get: { travelDraft.hasArrivalTime }, set: { newValue in updateTravel { $0.hasArrivalTime = newValue } })
    }

    var travelArrival: Binding<Date> {
        Binding(get: { travelDraft.arrivalTime }, set: { newValue in updateTravel { $0.arrivalTime = newValue } })
    }

    var stayPlace: Binding<String> {
        Binding(get: { stayDraft.place }, set: { newValue in updateStay { $0.place = newValue } })
    }

    var stayHasCheckIn: Binding<Bool> {
        Binding(get: { stayDraft.hasCheckIn }, set: { newValue in updateStay { $0.hasCheckIn = newValue } })
    }

    var stayCheckIn: Binding<Date> {
        Binding(get: { stayDraft.checkIn }, set: { newValue in updateStay { $0.checkIn = newValue } })
    }

    var stayHasCheckOut: Binding<Bool> {
        Binding(get: { stayDraft.hasCheckOut }, set: { newValue in updateStay { $0.hasCheckOut = newValue } })
    }

    var stayCheckOut: Binding<Date> {
        Binding(get: { stayDraft.checkOut }, set: { newValue in updateStay { $0.checkOut = newValue } })
    }
}
