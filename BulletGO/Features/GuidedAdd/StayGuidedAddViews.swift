import SwiftUI

struct StayGuidedAddStack: View {
    var draft: StayAddDraft
    var step: GuidedAddStep
    var search: (any PlaceSearching)?
    var update: ((inout StayAddDraft) -> Void) -> Void
    var onSkipCheckIn: () -> Void
    var onSkipCheckOut: () -> Void
    var onJump: (GuidedAddStep) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isReview: Bool { step == .stayReview }
    private var accessory: GuidedAddFactAccessory { isReview ? .chevron : .check }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StayPlaceStepView(
                    draft: draft,
                    search: search,
                    isActive: step == .stayPlace,
                    accessory: accessory,
                    onJump: { onJump(.stayPlace) },
                    update: update
                )

                if step != .stayPlace {
                    StayDateStepView(
                        title: "チェックイン",
                        date: draft.checkIn,
                        hasDate: draft.hasCheckIn,
                        isActive: step == .stayCheckIn,
                        accessory: accessory,
                        skipID: AccessibilityID.guidedAddSkip,
                        selectedID: isReview ? AccessibilityID.guidedAddReviewDate : AccessibilityID.guidedAddDateSelected,
                        onSelect: { date in update { $0.checkIn = date; $0.hasCheckIn = true } },
                        onSkip: onSkipCheckIn,
                        onJump: { onJump(.stayCheckIn) }
                    )
                }

                if step == .stayCheckOut || isReview {
                    StayDateStepView(
                        title: "チェックアウト",
                        date: draft.checkOut,
                        hasDate: draft.hasCheckOut,
                        isActive: step == .stayCheckOut,
                        accessory: accessory,
                        skipID: AccessibilityID.guidedAddSkip,
                        selectedID: isReview ? AccessibilityID.guidedAddReviewTime : AccessibilityID.guidedAddDateSelected,
                        onSelect: { date in update { $0.checkOut = date; $0.hasCheckOut = true } },
                        onSkip: onSkipCheckOut,
                        onJump: { onJump(.stayCheckOut) }
                    )
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.bottom, 24)
            .animation(GuidedAddMotion.card(reduceMotion), value: step)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct StayPlaceStepView: View {
    var draft: StayAddDraft
    var search: (any PlaceSearching)?
    var isActive: Bool = true
    var accessory: GuidedAddFactAccessory = .check
    var onJump: () -> Void = {}
    var update: ((inout StayAddDraft) -> Void) -> Void

    @State private var placeSearch = PlaceSearchModel()
    @FocusState private var placeFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isActive {
                expandedPlace
            } else {
                GuidedAddCompactFact(
                    title: "宿泊先",
                    value: placeText,
                    accessory: accessory,
                    accessibilityID: AccessibilityID.guidedAddStayPlace
                ) {
                    onJump()
                }
            }
        }
        .animation(GuidedAddMotion.card(reduceMotion), value: isActive)
        .onChange(of: isActive) { _, active in
            if active {
                placeFocused = true
            } else {
                placeFocused = false
            }
        }
        .onAppear {
            placeSearch.search = search
            if let place = draft.placeReference {
                placeSearch.restoreSelected(place)
            }
            if isActive {
                placeFocused = true
            }
        }
    }

    private var expandedPlace: some View {
        GuidedAddCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("どこに泊まる？")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                GuidedAddInnerSearchField(
                    title: "宿泊先",
                    text: placeBinding,
                    accessibilityID: AccessibilityID.guidedAddStayPlace,
                    focused: $placeFocused,
                    onSubmit: { placeSearch.searchNow() }
                )
                if placeSearch.isSearching || placeSearch.isResolving {
                    ProgressView()
                        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                }
                ForEach(placeSearch.completions) { completion in
                    Button {
                        Task { await choose(completion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: completion.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(GuidedAddPalette.primaryText)
                            if !completion.subtitle.isEmpty {
                                Text(verbatim: completion.subtitle)
                                    .font(DesignTokens.Typography.footnote)
                                    .foregroundStyle(GuidedAddPalette.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                    }
                    .accessibilityIdentifier(AccessibilityID.placeSearchResult(completion.id))
                }
                if let selected = draft.placeReference, selected.isSearchResolved {
                    HStack {
                        Text(verbatim: selected.name)
                            .font(DesignTokens.Typography.headline)
                        Spacer()
                        GuidedAddCheck()
                    }
                    .accessibilityIdentifier(AccessibilityID.placeSearchSelected)
                }
            }
            .padding(18)
        }
    }

    private var placeText: String {
        let place = draft.place.trimmingCharacters(in: .whitespacesAndNewlines)
        return place.isEmpty ? String(localized: "まだ決めていない") : place
    }

    private var placeBinding: Binding<String> {
        Binding(
            get: { draft.place },
            set: { newValue in
                placeSearch.updateQuery(newValue)
                update {
                    $0.place = newValue
                    if placeSearch.selected == nil {
                        $0.placeReference = nil
                    }
                }
            }
        )
    }

    private func choose(_ completion: PlaceSearchCompletion) async {
        await placeSearch.select(completion)
        guard let selected = placeSearch.selected else { return }
        update {
            $0.placeReference = selected
            $0.place = selected.name
        }
        placeFocused = false
    }
}

struct StayDateStepView: View {
    var title: LocalizedStringKey
    var date: Date
    var hasDate: Bool
    var isActive: Bool = true
    var accessory: GuidedAddFactAccessory = .check
    var skipID: String
    var selectedID: String = AccessibilityID.guidedAddDateSelected
    var onSelect: (Date) -> Void
    var onSkip: () -> Void
    var onJump: () -> Void = {}

    @State private var dateExpanded: Bool
    @State private var displayedMonth: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: LocalizedStringKey,
        date: Date,
        hasDate: Bool,
        isActive: Bool = true,
        accessory: GuidedAddFactAccessory = .check,
        skipID: String,
        selectedID: String = AccessibilityID.guidedAddDateSelected,
        onSelect: @escaping (Date) -> Void,
        onSkip: @escaping () -> Void,
        onJump: @escaping () -> Void = {}
    ) {
        self.title = title
        self.date = date
        self.hasDate = hasDate
        self.isActive = isActive
        self.accessory = accessory
        self.skipID = skipID
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.onSkip = onSkip
        self.onJump = onJump
        _dateExpanded = State(initialValue: isActive && !hasDate)
        _displayedMonth = State(initialValue: date)
    }

    var body: some View {
        GuidedAddCard {
            if isActive, dateExpanded || !hasDate {
                expandedDate
            } else {
                Button {
                    if isActive {
                        dateExpanded = true
                    } else {
                        onJump()
                    }
                } label: {
                    compactRow
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(selectedID)
            }
        }
        .animation(GuidedAddMotion.card(reduceMotion), value: dateExpanded)
        .animation(GuidedAddMotion.card(reduceMotion), value: isActive)
        .onChange(of: isActive) { _, active in
            dateExpanded = active && !hasDate
        }
    }

    private var expandedDate: some View {
        VStack(alignment: .leading, spacing: 0) {
            GuidedAddDateGrid(
                month: displayedMonth,
                selected: hasDate ? date : nil,
                onSelect: { value in
                    onSelect(value)
                    displayedMonth = value
                    dateExpanded = false
                },
                onChangeMonth: { delta in
                    displayedMonth = GuidedAddCopy.tokyoCalendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
                }
            )
            .padding(18)
            Button(action: onSkip) {
                HStack {
                    Text("日付はあとで決める")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                    Spacer()
                    Text("→")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .frame(minHeight: DesignTokens.TapTarget.minimum)
            }
            .accessibilityIdentifier(skipID)
        }
    }

    private var compactRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                Text(verbatim: hasDate ? GuidedAddCopy.dateText(date) : String(localized: "まだ決めていない"))
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
            }
            Spacer()
            compactAccessory
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var compactAccessory: some View {
        switch accessory {
        case .check:
            GuidedAddCheck()
        case .chevron:
            Text("›")
                .font(.system(size: 22))
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }
}
