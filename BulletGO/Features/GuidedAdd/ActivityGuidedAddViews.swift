import SwiftUI

struct ActivityGuidedAddStack: View {
    var draft: ActivityAddDraft
    var step: GuidedAddStep
    var search: (any PlaceSearching)?
    var update: ((inout ActivityAddDraft) -> Void) -> Void
    var onSkipTiming: () -> Void
    var onJump: (GuidedAddStep) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isReview: Bool { step == .activityReview }
    private var accessory: GuidedAddFactAccessory { isReview ? .chevron : .check }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActivityWhatStepView(
                    draft: draft,
                    search: search,
                    isActive: step == .activityWhat,
                    accessory: accessory,
                    onJump: { onJump(.activityWhat) },
                    update: update
                )

                if step != .activityWhat {
                    ActivityWhenStepView(
                        draft: draft,
                        isActive: step == .activityDate,
                        accessory: accessory,
                        onJump: { onJump(.activityDate) },
                        update: update
                    )
                }

                if step == .activityTiming || isReview {
                    ActivityTimingStepView(
                        draft: draft,
                        isActive: step == .activityTiming,
                        accessory: accessory,
                        onJump: { onJump(.activityTiming) },
                        update: update,
                        onSkip: onSkipTiming
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

struct ActivityWhatStepView: View {
    var draft: ActivityAddDraft
    var search: (any PlaceSearching)?
    var isActive: Bool = true
    var accessory: GuidedAddFactAccessory = .check
    var onJump: () -> Void = {}
    var update: ((inout ActivityAddDraft) -> Void) -> Void

    @State private var placeSearch = PlaceSearchModel()
    @FocusState private var titleFocused: Bool
    @FocusState private var placeFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isActive {
                titleCard
                placeCard
            } else {
                GuidedAddCompactFact(
                    title: "予定",
                    value: summaryText,
                    accessory: accessory,
                    accessibilityID: AccessibilityID.guidedAddTitle
                ) {
                    onJump()
                }
                GuidedAddCompactFact(
                    title: "場所",
                    value: placeText,
                    accessory: accessory,
                    accessibilityID: draft.placeReference?.isSearchResolved == true
                        ? AccessibilityID.placeSearchSelected
                        : AccessibilityID.guidedAddPlace
                ) {
                    onJump()
                }
            }
        }
        .animation(GuidedAddMotion.card(reduceMotion), value: isActive)
        .onChange(of: isActive) { _, active in
            if !active {
                titleFocused = false
                placeFocused = false
            }
        }
        .onAppear {
            placeSearch.search = search
            if let place = draft.placeReference {
                placeSearch.restoreSelected(place)
            }
            if isActive {
                titleFocused = draft.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    private var titleCard: some View {
        GuidedAddCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("何をする？")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                TextField("金閣寺、昼食…", text: titleBinding)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: GuidedAddMetrics.inputHeight)
                    .background(
                        GuidedAddPalette.canvas,
                        in: RoundedRectangle(cornerRadius: GuidedAddMetrics.inputRadius, style: .continuous)
                    )
                    .focused($titleFocused)
                    .accessibilityIdentifier(AccessibilityID.guidedAddTitle)
            }
            .padding(18)
        }
    }

    private var placeCard: some View {
        GuidedAddCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("場所")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                GuidedAddInnerSearchField(
                    title: "場所",
                    text: placeBinding,
                    accessibilityID: AccessibilityID.guidedAddPlace,
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("選んだ場所")
                                .font(DesignTokens.Typography.footnote)
                                .foregroundStyle(GuidedAddPalette.secondaryText)
                            Text(verbatim: selected.name)
                                .font(DesignTokens.Typography.headline)
                        }
                        Spacer()
                        GuidedAddCheck()
                    }
                    .accessibilityIdentifier(AccessibilityID.placeSearchSelected)
                }
            }
            .padding(18)
        }
    }

    private var summaryText: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let place = draft.place.trimmingCharacters(in: .whitespacesAndNewlines)
        return place.isEmpty ? String(localized: "まだ決めていない") : place
    }

    private var placeText: String {
        let place = draft.place.trimmingCharacters(in: .whitespacesAndNewlines)
        return place.isEmpty ? String(localized: "まだ決めていない") : place
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { draft.title },
            set: { newValue in update { $0.title = newValue } }
        )
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
            if $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                $0.title = selected.name
            }
        }
        placeFocused = false
    }
}

struct ActivityWhenStepView: View {
    var draft: ActivityAddDraft
    var isActive: Bool = true
    var accessory: GuidedAddFactAccessory = .check
    var onJump: () -> Void = {}
    var update: ((inout ActivityAddDraft) -> Void) -> Void

    @State private var dateExpanded: Bool
    @State private var displayedMonth: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        draft: ActivityAddDraft,
        isActive: Bool = true,
        accessory: GuidedAddFactAccessory = .check,
        onJump: @escaping () -> Void = {},
        update: @escaping ((inout ActivityAddDraft) -> Void) -> Void
    ) {
        self.draft = draft
        self.isActive = isActive
        self.accessory = accessory
        self.onJump = onJump
        self.update = update
        _dateExpanded = State(initialValue: isActive && !draft.hasDate)
        _displayedMonth = State(initialValue: draft.date)
    }

    var body: some View {
        GuidedAddCard {
            if isActive, dateExpanded || !draft.hasDate {
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
                .accessibilityIdentifier(AccessibilityID.guidedAddDateSelected)
            }
        }
        .animation(GuidedAddMotion.card(reduceMotion), value: dateExpanded)
        .animation(GuidedAddMotion.card(reduceMotion), value: isActive)
        .onChange(of: isActive) { _, active in
            dateExpanded = active && !draft.hasDate
        }
    }

    private var expandedDate: some View {
        VStack(alignment: .leading, spacing: 0) {
            GuidedAddDateGrid(
                month: displayedMonth,
                selected: draft.hasDate ? draft.date : nil,
                onSelect: { date in
                    update {
                        $0.date = date
                        $0.hasDate = true
                    }
                    displayedMonth = date
                    dateExpanded = false
                },
                onChangeMonth: { delta in
                    displayedMonth = GuidedAddCopy.tokyoCalendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
                }
            )
            .padding(18)
            Button {
                update { $0.hasDate = false }
                dateExpanded = false
            } label: {
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
            .accessibilityIdentifier(AccessibilityID.guidedAddSkipTime)
        }
    }

    private var compactRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("日付")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                Text(verbatim: draft.hasDate ? GuidedAddCopy.dateText(draft.date) : String(localized: "未配置"))
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

struct ActivityTimingStepView: View {
    var draft: ActivityAddDraft
    var isActive: Bool = true
    var accessory: GuidedAddFactAccessory = .check
    var onJump: () -> Void = {}
    var update: ((inout ActivityAddDraft) -> Void) -> Void
    var onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GuidedAddCard {
            if isActive {
                expandedTiming
            } else {
                Button(action: onJump) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("時刻")
                                .font(DesignTokens.Typography.footnote)
                                .foregroundStyle(GuidedAddPalette.secondaryText)
                            Text(verbatim: timeText)
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
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.guidedAddReviewTime)
            }
        }
        .animation(GuidedAddMotion.card(reduceMotion), value: isActive)
        .animation(GuidedAddMotion.card(reduceMotion), value: draft.timing)
    }

    private var expandedTiming: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("時刻")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                ForEach(ActivityTimingChoice.allCases) { choice in
                    GuidedAddTimeChip(title: choice.title, isSelected: draft.timing == choice) {
                        update { $0.timing = choice }
                    }
                }
            }
            if draft.timing == .start || draft.timing == .range {
                GuidedAddClockWheel(
                    hour: hourBinding(isEnd: false),
                    minute: minuteBinding(isEnd: false),
                    onInteract: {}
                )
            }
            if draft.timing == .range {
                Text("終了")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                GuidedAddClockWheel(
                    hour: hourBinding(isEnd: true),
                    minute: minuteBinding(isEnd: true),
                    onInteract: {}
                )
            }
            Button(action: onSkip) {
                HStack {
                    Text("時刻はあとで決める")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                    Spacer()
                    Text("→")
                }
                .frame(minHeight: DesignTokens.TapTarget.minimum)
            }
            .accessibilityIdentifier(AccessibilityID.guidedAddSkip)
        }
        .padding(18)
    }

    private var timeText: String {
        switch draft.timing {
        case .none: String(localized: "まだ決めていない")
        case .allDay: String(localized: "終日")
        case .start: "\(String(localized: "開始")) \(GuidedAddCopy.clockText(draft.startTime))"
        case .range: "\(GuidedAddCopy.clockText(draft.startTime)) – \(GuidedAddCopy.clockText(draft.endTime))"
        }
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

    private func hourBinding(isEnd: Bool) -> Binding<Int> {
        Binding(
            get: { GuidedAddCopy.tokyoCalendar.component(.hour, from: isEnd ? draft.endTime : draft.startTime) },
            set: { hour in apply(hour: hour, minute: minute(isEnd: isEnd), isEnd: isEnd) }
        )
    }

    private func minuteBinding(isEnd: Bool) -> Binding<Int> {
        Binding(
            get: { (GuidedAddCopy.tokyoCalendar.component(.minute, from: isEnd ? draft.endTime : draft.startTime) / 10) * 10 },
            set: { minute in apply(hour: hour(isEnd: isEnd), minute: minute, isEnd: isEnd) }
        )
    }

    private func hour(isEnd: Bool) -> Int {
        GuidedAddCopy.tokyoCalendar.component(.hour, from: isEnd ? draft.endTime : draft.startTime)
    }

    private func minute(isEnd: Bool) -> Int {
        (GuidedAddCopy.tokyoCalendar.component(.minute, from: isEnd ? draft.endTime : draft.startTime) / 10) * 10
    }

    private func apply(hour: Int, minute: Int, isEnd: Bool) {
        var components = GuidedAddCopy.tokyoCalendar.dateComponents([.year, .month, .day], from: draft.date)
        components.hour = hour
        components.minute = minute
        let date = GuidedAddCopy.tokyoCalendar.date(from: components) ?? (isEnd ? draft.endTime : draft.startTime)
        update {
            if isEnd {
                $0.endTime = date
            } else {
                $0.startTime = date
            }
        }
    }
}
