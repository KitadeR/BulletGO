import MapKit
import SwiftUI

enum TravelPlaceField {
    case origin
    case destination
}

struct TravelPlacesStepView: View {
    var draft: LegAddDraft
    var search: (any PlaceSearching)?
    var isActive: Bool = true
    var factAccessory: GuidedAddFactAccessory = .check
    var originSelectedID: String = AccessibilityID.guidedAddOriginSelected
    var destinationSelectedID: String = AccessibilityID.guidedAddDestinationSelected
    var requestedField: TravelPlaceField? = nil
    var onConsumedRequest: () -> Void = {}
    var onSelectCompact: (TravelPlaceField) -> Void = { _ in }
    var update: ((inout LegAddDraft) -> Void) -> Void

    @State private var originSearch = PlaceSearchModel()
    @State private var destinationSearch = PlaceSearchModel()
    @State private var originQuery = ""
    @State private var destinationQuery = ""
    @State private var activeField: TravelPlaceField? = .origin
    @State private var didInitialize = false
    @FocusState private var originFocused: Bool
    @FocusState private var destinationFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            placeCard(
                field: .origin,
                title: "出発地",
                fieldID: AccessibilityID.guidedAddOrigin,
                selectedID: originSelectedID,
                model: originSearch,
                place: draft.originPlace,
                focused: $originFocused
            )
            GuidedAddRouteArrow()
            placeCard(
                field: .destination,
                title: "到着地",
                fieldID: AccessibilityID.guidedAddDestination,
                selectedID: destinationSelectedID,
                model: destinationSearch,
                place: draft.destinationPlace,
                focused: $destinationFocused
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(GuidedAddMotion.card(reduceMotion), value: activeField)
        .animation(GuidedAddMotion.card(reduceMotion), value: isActive)
        .onChange(of: isActive) { _, active in
            if active, let requestedField {
                expand(requestedField)
                onConsumedRequest()
            } else if !active {
                activeField = nil
                originFocused = false
                destinationFocused = false
            }
        }
        .onChange(of: originQuery) { _, newValue in
            guard originFocused else { return }
            applyQuery(newValue, field: .origin, model: originSearch)
        }
        .onChange(of: destinationQuery) { _, newValue in
            guard destinationFocused else { return }
            applyQuery(newValue, field: .destination, model: destinationSearch)
        }
        .onAppear {
            originSearch.search = search
            destinationSearch.search = search
            guard !didInitialize else { return }
            didInitialize = true
            originQuery = draft.origin
            destinationQuery = draft.destination
            if let origin = draft.originPlace, origin.isSearchResolved {
                originSearch.restoreSelected(origin)
            }
            if let destination = draft.destinationPlace, destination.isSearchResolved {
                destinationSearch.restoreSelected(destination)
            }
            if !isActive {
                activeField = nil
            } else if draft.hasResolvedOrigin, !draft.hasResolvedDestination {
                activeField = .destination
                destinationFocused = true
            } else if draft.hasResolvedOrigin, draft.hasResolvedDestination {
                activeField = nil
            } else {
                activeField = .origin
                originFocused = true
            }
        }
    }

    @ViewBuilder
    private func placeCard(
        field: TravelPlaceField,
        title: LocalizedStringKey,
        fieldID: String,
        selectedID: String,
        model: PlaceSearchModel,
        place: PlaceReference?,
        focused: FocusState<Bool>.Binding
    ) -> some View {
        let expanded = isActive && activeField == field
        let resolved = place?.isSearchResolved == true
        GuidedAddCard {
            VStack(alignment: .leading, spacing: 16) {
                if expanded {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                    GuidedAddInnerSearchField(
                        title: title,
                        text: queryBinding(field: field),
                        accessibilityID: fieldID,
                        focused: focused,
                        onSubmit: { model.searchNow() }
                    )
                    searchStatus(model: model)
                    ForEach(model.completions) { completion in
                        Button {
                            Task { await choose(completion, field: field, model: model) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: completion.title)
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundStyle(GuidedAddPalette.primaryText)
                                if !completion.subtitle.isEmpty {
                                    Text(verbatim: PlaceDisplayFormatting.guidedAddSubtitle(
                                        address: completion.subtitle,
                                        category: nil
                                    ))
                                    .font(DesignTokens.Typography.footnote)
                                    .foregroundStyle(GuidedAddPalette.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                        }
                        .disabled(model.isResolving)
                        .accessibilityLabel(Text(verbatim: completion.title))
                        .accessibilityHint("Choose this place")
                        .accessibilityValue(Text(verbatim: completion.subtitle))
                        .accessibilityIdentifier(AccessibilityID.placeSearchResult(completion.id))
                    }
                } else if resolved, let place {
                    Button {
                        selectCompact(field)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(DesignTokens.Typography.footnote)
                                    .foregroundStyle(GuidedAddPalette.secondaryText)
                                Text(verbatim: place.name)
                                    .font(Font.title3.weight(.semibold))
                                    .foregroundStyle(GuidedAddPalette.primaryText)
                                if let subtitle = place.japaneseCategorySubtitle {
                                    Text(verbatim: subtitle)
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundStyle(GuidedAddPalette.secondaryText)
                                }
                            }
                            Spacer(minLength: 8)
                            factAccessoryView
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(selectedID)
                } else {
                    Button {
                        selectCompact(field)
                    } label: {
                        Text(title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(GuidedAddPalette.primaryText)
                            .frame(maxWidth: .infinity, minHeight: GuidedAddMetrics.compactEmpty - 34, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(fieldID)
                }
            }
            .padding(18)
            .frame(minHeight: expanded ? 280 : (resolved ? GuidedAddMetrics.compactSelected : GuidedAddMetrics.compactEmpty), alignment: .top)
        }
        .geometryGroup()
    }

    @ViewBuilder
    private var factAccessoryView: some View {
        switch factAccessory {
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

    @ViewBuilder
    private func searchStatus(model: PlaceSearchModel) -> some View {
        if model.isSearching || model.isResolving {
            ProgressView()
                .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                .accessibilityLabel("Searching")
        }
        if model.failure != nil {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("場所を検索できませんでした")
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .accessibilityIdentifier(AccessibilityID.placeSearchFailed)
                Button("再試行") { model.retry() }
                    .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.placeSearchRetry)
            }
        } else if model.showsEmptyResults {
            Text("場所が見つかりません")
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                .accessibilityIdentifier(AccessibilityID.placeSearchEmpty)
        }
    }

    private func selectCompact(_ field: TravelPlaceField) {
        if isActive {
            expand(field)
        } else {
            onSelectCompact(field)
        }
    }

    private func expand(_ field: TravelPlaceField) {
        withAnimation(GuidedAddMotion.card(reduceMotion)) {
            activeField = field
        }
        switch field {
        case .origin:
            originQuery = draft.origin
            originFocused = true
            if draft.originPlace != nil {
                originSearch.reopenForReselection()
            }
        case .destination:
            destinationQuery = draft.destination
            destinationFocused = true
            if draft.destinationPlace != nil {
                destinationSearch.reopenForReselection()
            }
        }
    }

    private func queryBinding(field: TravelPlaceField) -> Binding<String> {
        Binding(
            get: { field == .origin ? originQuery : destinationQuery },
            set: { newValue in
                if field == .origin {
                    originQuery = newValue
                } else {
                    destinationQuery = newValue
                }
            }
        )
    }

    private func applyQuery(_ newValue: String, field: TravelPlaceField, model: PlaceSearchModel) {
        let hadSelection = model.selected != nil
        model.search = search
        model.updateQuery(newValue)
        update { draft in
            switch field {
            case .origin:
                draft.origin = newValue
                if hadSelection, model.selected == nil {
                    draft.originPlace = nil
                }
            case .destination:
                draft.destination = newValue
                if hadSelection, model.selected == nil {
                    draft.destinationPlace = nil
                }
            }
        }
    }

    private func choose(
        _ completion: PlaceSearchCompletion,
        field: TravelPlaceField,
        model: PlaceSearchModel
    ) async {
        await model.select(completion)
        guard let selected = model.selected, selected.isSearchResolved else { return }
        let destinationAlreadyResolved = draft.hasResolvedDestination
        let originAlreadyResolved = draft.hasResolvedOrigin
        switch field {
        case .origin:
            originFocused = false
            originQuery = selected.name
            update {
                $0.originPlace = selected
                $0.origin = selected.name
            }
            withAnimation(GuidedAddMotion.card(reduceMotion)) {
                activeField = destinationAlreadyResolved ? nil : .destination
            }
            if !destinationAlreadyResolved {
                destinationFocused = true
            }
        case .destination:
            destinationFocused = false
            destinationQuery = selected.name
            update {
                $0.destinationPlace = selected
                $0.destination = selected.name
            }
            withAnimation(GuidedAddMotion.card(reduceMotion)) {
                activeField = originAlreadyResolved ? nil : .origin
            }
            if !originAlreadyResolved {
                originFocused = true
            }
        }
    }
}

struct TravelHowStepView: View {
    var draft: LegAddDraft
    var onSelectMode: (TransportMode) -> Void
    var onOpenMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                ForEach(TravelGuidedAdd.modes, id: \.self) { mode in
                    Button {
                        onSelectMode(mode)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(TravelGuidedAdd.modeTitle(mode))
                                    .font(Font.title3.weight(.semibold))
                                    .foregroundStyle(GuidedAddPalette.primaryText)
                                    .padding(.leading, 8)
                                HStack {
                                    transportIcon(mode)
                                    Spacer()
                                }
                                .padding(.leading, 16)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 7)
                            if draft.mode == mode {
                                GuidedAddCheck()
                                    .padding(.top, 8)
                                    .padding(.trailing, 12)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: GuidedAddMetrics.howHeight, alignment: .leading)
                        .background(
                            GuidedAddPalette.mutedFill,
                            in: RoundedRectangle(cornerRadius: GuidedAddMetrics.howRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.guidedAddMode(mode))
                    .accessibilityAddTraits(draft.mode == mode ? [.isSelected] : [])
                }
                Button(action: onOpenMaps) {
                    HStack {
                        Text("Apple Mapsで経路を見る")
                        Spacer()
                        Text("→")
                    }
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum)
                }
                .disabled(!draft.hasResolvedOrigin || !draft.hasResolvedDestination)
                .accessibilityIdentifier(AccessibilityID.guidedAddOpenMaps)
                .padding(.top, draft.mode == nil ? 24 : 8)
        }
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

struct TravelWhenStepView: View {
    var draft: LegAddDraft
    var isInteractive: Bool = true
    var accessory: GuidedAddFactAccessory = .check
    var dateID: String = AccessibilityID.guidedAddDateSelected
    var timeID: String = AccessibilityID.guidedAddReviewTime
    var onJump: () -> Void = {}
    var update: ((inout LegAddDraft) -> Void) -> Void

    @State private var dateExpanded: Bool
    @State private var timeExpanded: Bool
    @State private var displayedMonth: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        draft: LegAddDraft,
        isInteractive: Bool = true,
        accessory: GuidedAddFactAccessory = .check,
        dateID: String = AccessibilityID.guidedAddDateSelected,
        timeID: String = AccessibilityID.guidedAddReviewTime,
        onJump: @escaping () -> Void = {},
        update: @escaping ((inout LegAddDraft) -> Void) -> Void
    ) {
        self.draft = draft
        self.isInteractive = isInteractive
        self.accessory = accessory
        self.dateID = dateID
        self.timeID = timeID
        self.onJump = onJump
        self.update = update
        _dateExpanded = State(initialValue: isInteractive && !draft.hasDate)
        _timeExpanded = State(initialValue: isInteractive && draft.hasDate && !Self.isTimeSettled(draft))
        _displayedMonth = State(initialValue: draft.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                dateCard
                timeCard
            }
        .animation(GuidedAddMotion.card(reduceMotion), value: dateExpanded)
        .animation(GuidedAddMotion.card(reduceMotion), value: timeExpanded)
        .animation(GuidedAddMotion.card(reduceMotion), value: draft.timeKind)
        .animation(GuidedAddMotion.card(reduceMotion), value: draft.clockConfirmed)
        .animation(GuidedAddMotion.card(reduceMotion), value: isInteractive)
    }

    @ViewBuilder
    private var dateCard: some View {
        GuidedAddCard {
            if isInteractive, dateExpanded || !draft.hasDate {
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
                        timeExpanded = !draft.skippedTime
                            && draft.timeKind != .firstTrain
                            && draft.timeKind != .lastTrain
                    },
                    onChangeMonth: { delta in
                        displayedMonth = GuidedAddCopy.tokyoCalendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
                    }
                )
                .padding(18)
            } else if draft.hasDate {
                Button {
                    if isInteractive {
                        dateExpanded = true
                        timeExpanded = false
                    } else {
                        onJump()
                    }
                } label: {
                    compactRow(title: "日付", value: GuidedAddCopy.dateText(draft.date), accessory: accessory)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(dateID)
            }
        }
        .geometryGroup()
    }

    @ViewBuilder
    private var timeCard: some View {
        GuidedAddCard {
            if !draft.hasDate {
                compactRow(title: "時刻", value: String(localized: "日付を選ぶと設定できる"), accessory: .none)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
            } else if isInteractive, timeExpanded || !Self.isTimeSettled(draft) {
                expandedTime
            } else {
                Button {
                    if isInteractive {
                        timeExpanded = true
                        dateExpanded = false
                    } else {
                        onJump()
                    }
                } label: {
                    compactRow(title: "時刻", value: settledTimeText, accessory: accessory)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(timeID)
            }
        }
        .geometryGroup()
    }

    private var expandedTime: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("時刻")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                ForEach([TravelTimeKind.departure, .arrival, .firstTrain, .lastTrain]) { kind in
                    GuidedAddTimeChip(title: kind.title, isSelected: draft.timeKind == kind) {
                        selectKind(kind)
                    }
                    .accessibilityIdentifier(AccessibilityID.guidedAddTimeKind(kind))
                }
            }
            if draft.timeKind.needsClock {
                GuidedAddClockWheel(
                    hour: clockHourBinding,
                    minute: clockMinuteBinding,
                    onInteract: confirmClock
                )
            }
            Button {
                update {
                    $0.timeKind = .undecided
                    $0.clockConfirmed = false
                    $0.skippedTime = true
                }
                timeExpanded = false
            } label: {
                HStack {
                    Text("時刻はあとで決める")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                    Spacer()
                    Text("→")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(GuidedAddPalette.primaryText)
                }
                .frame(minHeight: DesignTokens.TapTarget.minimum)
            }
            .accessibilityIdentifier(AccessibilityID.guidedAddSkipTime)
        }
        .padding(18)
    }

    private func compactRow(title: LocalizedStringKey, value: String, accessory: GuidedAddFactAccessory) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                Text(verbatim: value)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
            }
            Spacer()
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
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var settledTimeText: String {
        switch draft.timeKind {
        case .undecided:
            String(localized: "あとで決める")
        case .firstTrain, .lastTrain:
            String(localized: draft.timeKind.title)
        case .departure:
            "\(String(localized: "出発")) \(GuidedAddCopy.clockText(draft.departureTime))"
        case .arrival:
            "\(String(localized: "到着")) \(GuidedAddCopy.clockText(draft.arrivalTime))"
        }
    }

    private func selectKind(_ kind: TravelTimeKind) {
        update {
            $0.timeKind = kind
            $0.clockConfirmed = false
            $0.skippedTime = false
        }
        if !kind.needsClock {
            timeExpanded = false
        }
    }

    private func confirmClock() {
        update { $0.clockConfirmed = true }
    }

    private var clockHourBinding: Binding<Int> {
        Binding(
            get: { GuidedAddCopy.tokyoCalendar.component(.hour, from: clockDate) },
            set: { hour in applyClock(hour: hour, minute: clockMinute) }
        )
    }

    private var clockMinuteBinding: Binding<Int> {
        Binding(
            get: { roundedMinute(GuidedAddCopy.tokyoCalendar.component(.minute, from: clockDate)) },
            set: { minute in applyClock(hour: clockHour, minute: minute) }
        )
    }

    private var clockDate: Date {
        draft.timeKind == .arrival ? draft.arrivalTime : draft.departureTime
    }

    private var clockHour: Int {
        GuidedAddCopy.tokyoCalendar.component(.hour, from: clockDate)
    }

    private var clockMinute: Int {
        roundedMinute(GuidedAddCopy.tokyoCalendar.component(.minute, from: clockDate))
    }

    private func roundedMinute(_ minute: Int) -> Int {
        Int((Double(minute) / 10.0).rounded()) * 10 % 60
    }

    private func applyClock(hour: Int, minute: Int) {
        var components = GuidedAddCopy.tokyoCalendar.dateComponents([.year, .month, .day], from: draft.date)
        components.hour = hour
        components.minute = minute
        let date = GuidedAddCopy.tokyoCalendar.date(from: components) ?? clockDate
        update { value in
            if value.timeKind == .arrival {
                value.arrivalTime = date
            } else {
                value.departureTime = date
            }
        }
    }

    private static func isTimeSettled(_ draft: LegAddDraft) -> Bool {
        switch draft.timeKind {
        case .undecided:
            draft.skippedTime
        case .firstTrain, .lastTrain:
            true
        case .departure, .arrival:
            draft.clockConfirmed
        }
    }
}

struct TravelReviewStepView: View {
    var draft: LegAddDraft
    var onJump: (GuidedAddStep) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                reviewRow("出発地", draft.origin, step: .travelPlaces, id: AccessibilityID.guidedAddReviewFrom)
                reviewRow("到着地", draft.destination, step: .travelPlaces, id: AccessibilityID.guidedAddReviewTo)
                reviewRow(
                    "行き方",
                    draft.mode.map { String(localized: TravelGuidedAdd.modeTitle($0)) } ?? String(localized: "まだ決めていない"),
                    step: .travelMode,
                    id: AccessibilityID.guidedAddReviewHow
                )
                reviewRow("日付", formattedDate, step: .travelSchedule, id: AccessibilityID.guidedAddReviewDate)
                reviewRow("時刻", timeText, step: .travelSchedule, id: AccessibilityID.guidedAddReviewTime)
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var formattedDate: String {
        guard draft.hasDate else { return String(localized: "まだ決めていない") }
        return GuidedAddCopy.dateText(draft.date)
    }

    private var timeText: String {
        switch draft.timeKind {
        case .undecided:
            String(localized: "まだ決めていない")
        case .firstTrain, .lastTrain:
            String(localized: draft.timeKind.title)
        case .departure:
            "\(String(localized: "出発")) \(GuidedAddCopy.clockText(draft.departureTime))"
        case .arrival:
            "\(String(localized: "到着")) \(GuidedAddCopy.clockText(draft.arrivalTime))"
        }
    }

    private func reviewRow(
        _ title: LocalizedStringKey,
        _ value: String,
        step: GuidedAddStep,
        id: String
    ) -> some View {
        GuidedAddReviewRow(title: title, value: value, accessibilityID: id) {
            onJump(step)
        }
    }
}

struct TravelGuidedAddStack: View {
    var draft: LegAddDraft
    var step: GuidedAddStep
    var search: (any PlaceSearching)?
    var update: ((inout LegAddDraft) -> Void) -> Void
    var onSelectMode: (TransportMode) -> Void
    var onOpenMaps: () -> Void
    var onJump: (GuidedAddStep) -> Void

    @State private var requestedPlaceField: TravelPlaceField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isReview: Bool { step == .travelReview }
    private var accessory: GuidedAddFactAccessory { isReview ? .chevron : .check }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TravelPlacesStepView(
                    draft: draft,
                    search: search,
                    isActive: step == .travelPlaces,
                    factAccessory: accessory,
                    originSelectedID: isReview ? AccessibilityID.guidedAddReviewFrom : AccessibilityID.guidedAddOriginSelected,
                    destinationSelectedID: isReview ? AccessibilityID.guidedAddReviewTo : AccessibilityID.guidedAddDestinationSelected,
                    requestedField: requestedPlaceField,
                    onConsumedRequest: { requestedPlaceField = nil },
                    onSelectCompact: { field in
                        requestedPlaceField = field
                        onJump(.travelPlaces)
                    },
                    update: update
                )

                if step != .travelPlaces {
                    howSection
                }

                if step == .travelSchedule || isReview {
                    TravelWhenStepView(
                        draft: draft,
                        isInteractive: step == .travelSchedule,
                        accessory: accessory,
                        dateID: isReview ? AccessibilityID.guidedAddReviewDate : AccessibilityID.guidedAddDateSelected,
                        timeID: isReview ? AccessibilityID.guidedAddReviewTime : AccessibilityID.guidedAddReviewTime,
                        onJump: { onJump(.travelSchedule) },
                        update: update
                    )
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.bottom, 24)
            .animation(GuidedAddMotion.card(reduceMotion), value: step)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var howSection: some View {
        if step == .travelMode {
            TravelHowStepView(
                draft: draft,
                onSelectMode: onSelectMode,
                onOpenMaps: onOpenMaps
            )
        } else if let mode = draft.mode {
            GuidedAddCompactFact(
                title: "行き方",
                value: String(localized: TravelGuidedAdd.modeTitle(mode)),
                accessory: accessory,
                accessibilityID: isReview ? AccessibilityID.guidedAddReviewHow : AccessibilityID.guidedAddHowSelected
            ) {
                onJump(.travelMode)
            }
        }
    }
}

enum AppleMapsDirectionsHandoff {
    static func open(from: PlaceReference, to: PlaceReference) {
        guard let fromCoordinate = from.coordinate, fromCoordinate.isValid,
              let toCoordinate = to.coordinate, toCoordinate.isValid else {
            return
        }
        let source = MKMapItem(
            location: CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude),
            address: nil
        )
        source.name = from.name
        let destination = MKMapItem(
            location: CLLocation(latitude: toCoordinate.latitude, longitude: toCoordinate.longitude),
            address: nil
        )
        destination.name = to.name
        MKMapItem.openMaps(
            with: [source, destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault]
        )
    }
}
