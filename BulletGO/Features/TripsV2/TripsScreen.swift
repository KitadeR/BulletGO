import SwiftUI

struct TripsScreen: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @Environment(\.undoManager) private var undoManager

    @State private var selectedDate: LocalDate?
    @State private var programmaticTarget: LocalDate?
    @State private var didApplyInitialDay = false
    @State private var pendingDeleteTrip = false
    @State private var showProcessFailure = false
    @State private var editingDaySubtitle: LocalDate?
    @State private var quickContext: TripsQuickContextAnchor?
    @State private var pendingRouteAfterQuickContext: AppRoute?
    @State private var usesCompactNavigationTitle = false
    @State private var dateChipBarHeight = TripsV2Style.dateChipSize.height + 4
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffsetY: CGFloat = 0
    @State private var dayOffsets: [LocalDate: CGFloat] = [:]
    @State private var pendingJumpUntilLaidOut: LocalDate?

    var body: some View {
        Group {
            switch session.loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityID.tripTimelineLoading)
            case .failed:
                failedState
            case .empty:
                emptyState
            case .loaded:
                if let trip = session.trip {
                    loadedTimeline(trip)
                } else {
                    emptyState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TripsV2Style.canvas)
        .navigationTitle(Text(verbatim: session.trip?.name.value ?? "BulletGO"))
        .toolbarTitleDisplayMode(navigationTitleDisplayMode)
        .modifier(TripsNavigationSubtitle(text: tripDateRangeSubtitle))
        .toolbar { toolbarContent }
        .alert("Couldn’t update this trip", isPresented: $showProcessFailure) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: session.processState) { _, state in
            showProcessFailure = state == .failed
        }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: $pendingDeleteTrip,
            titleVisibility: .visible
        ) {
            Button("Delete trip", role: .destructive) {
                guard let id = session.trip?.id else { return }
                Task { _ = try? await session.deleteTrip(id: id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var navigationTitleDisplayMode: ToolbarTitleDisplayMode {
        guard session.loadState == .loaded, session.trip != nil else { return .inline }
        return usesCompactNavigationTitle ? .inline : .large
    }

    private var tripDateRangeSubtitle: String {
        guard session.loadState == .loaded, let trip = session.trip else { return "" }
        return TripsV2Formatting.dateRange(for: trip, locale: locale) ?? ""
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if session.loadState == .loaded, let trip = session.trip {
            ToolbarItem(placement: .secondaryAction) {
                Menu("Trip") {
                    Button("Switch trip", systemImage: "arrow.left.arrow.right") {
                        router.present(.switchTrip)
                    }
                    Button("Edit trip", systemImage: "pencil") {
                        router.present(.editTrip(trip.id))
                    }
                    Button("Map", systemImage: "map") {
                        router.push(.tripMap(trip.id))
                    }
                    Button("Saved places", systemImage: "star") {
                        router.push(.savedPlaces(trip.id))
                    }
                    Button("Delete trip", systemImage: "trash", role: .destructive) {
                        pendingDeleteTrip = true
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            Text("Your trip will appear here")
                .font(DesignTokens.Typography.headline)
            Text("Create a trip to start arranging dates, places, and journeys.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .multilineTextAlignment(.center)
            Button("Create trip") {
                router.present(.createTrip)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.createTripButton)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.tripTimelineEmpty)
    }

    private var failedState: some View {
        ContentUnavailableView {
            Label("Couldn’t load your trip", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Retry") {
                Task { await session.retry() }
            }
            .accessibilityIdentifier(AccessibilityID.tripTimelineRetry)
        }
        .accessibilityIdentifier(AccessibilityID.tripTimelineFailed)
    }

    private func loadedTimeline(_ trip: Trip) -> some View {
        let snapshot = ItineraryDayComposer.snapshot(
            for: trip,
            now: session.now,
            insertingEmptyDay: emptyDayToInsert(in: trip)
        )
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(snapshot.sections) { section in
                            TripsDaySection(
                                section: section,
                                trip: trip,
                                catalog: session.catalog,
                                locale: locale,
                                onAdd: { date, action in
                                    presentGuidedAdd(tripID: trip.id, action: action, date: date)
                                },
                                onMove: { row, offset in
                                    move(row, in: trip, offset: offset)
                                },
                                onMoveToDate: { row, date in
                                    move(row, in: trip, to: date)
                                },
                                onDelete: { row in
                                    delete(row, in: trip)
                                },
                                onEditSubtitle: { date in
                                    editingDaySubtitle = date
                                },
                                onOpenQuickContext: { row in
                                    quickContext = TripsQuickContextAnchor(row: row)
                                }
                            )
                            .background {
                                sectionAnchor(section)
                            }
                            .id(ItineraryDayComposer.scrollAnchor(for: section))
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 88)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .accessibilityIdentifier(AccessibilityID.tripTimeline)
                    } header: {
                        Group {
                            if !snapshot.dateOptions.isEmpty {
                                TripsDateStrip(
                                    options: snapshot.dateOptions,
                                    selectedDate: selectedDate,
                                    locale: locale,
                                    onSelect: { date in
                                        selectedDate = date
                                        jumpToDay(date)
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { _, height in
                            guard height > 0, abs(dateChipBarHeight - height) > 0.5 else { return }
                            dateChipBarHeight = height
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offsetY in
                scrollOffsetY = offsetY
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, scrolled in
                updateNavigationTitleMode(scrolled: scrolled)
            }
            .coordinateSpace(.named(tripsScrollSpace))
            .onPreferenceChange(DayOffsetPreference.self) { offsets in
                dayOffsets = offsets
                syncSelectedDate(with: offsets)
            }
            .onChange(of: dayOffsets) {
                applyInitialDayIfNeeded(snapshot)
                if let date = pendingJumpUntilLaidOut, dayOffsets[date] != nil {
                    pendingJumpUntilLaidOut = nil
                    performProgrammaticJump(to: date)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                TripsFloatingAdd(
                    selectedDate: selectedDate,
                    locale: locale,
                    onSelect: { action in
                        presentGuidedAdd(tripID: trip.id, action: action)
                    }
                )
                .padding(.trailing, 20)
                .padding(.bottom, 12)
                .ignoresSafeArea(.keyboard)
                .accessibilityIdentifier(AccessibilityID.tripsV2FloatingAdd)
            }
            .sheet(item: $editingDaySubtitle) { date in
                TripsDaySubtitleEditor(
                    date: date,
                    initialText: trip.daySubtitle(on: date) ?? "",
                    locale: locale,
                    onSave: { text in
                        Task {
                            _ = await session.process(.applyMutation(.setDaySubtitle(date, text)))
                        }
                        editingDaySubtitle = nil
                    },
                    onCancel: { editingDaySubtitle = nil }
                )
            }
            .sheet(item: $quickContext, onDismiss: {
                if let route = pendingRouteAfterQuickContext {
                    pendingRouteAfterQuickContext = nil
                    router.push(route)
                }
            }) { anchor in
                if let snapshot = TripsQuickContextComposer.snapshot(
                    row: anchor.row,
                    trip: trip,
                    catalog: session.catalog,
                    now: session.now
                ) {
                    TripsQuickContextSheet(snapshot: snapshot) { route in
                        pendingRouteAfterQuickContext = route
                        quickContext = nil
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func presentGuidedAdd(
        tripID: TripID,
        action: TripsFloatingAddAction,
        date: LocalDate? = nil
    ) {
        let kind: ItineraryAddKind
        switch action {
        case .activity: kind = .activity
        case .leg: kind = .travel
        case .stay: kind = .stay
        }
        router.present(.guidedAdd(tripID, kind, initialDate: date ?? selectedDate, seedPlace: nil))
    }

    private func updateNavigationTitleMode(scrolled: CGFloat) {
        if usesCompactNavigationTitle {
            if scrolled < tripsTitleHideDistance * 0.2 {
                usesCompactNavigationTitle = false
            }
        } else if scrolled >= tripsTitleHideDistance * 0.8 {
            usesCompactNavigationTitle = true
        }
    }

    private func emptyDayToInsert(in trip: Trip) -> LocalDate? {
        let candidate: LocalDate?
        if let selectedDate {
            candidate = selectedDate
        } else if !didApplyInitialDay {
            candidate = ItineraryDayComposer.initialDate(for: trip, now: session.now)
        } else {
            candidate = nil
        }
        guard let candidate else { return nil }
        let populated = Set(ItineraryDayComposer.sections(for: trip).compactMap(\.date))
        let options = ItineraryDayComposer.dateOptions(for: trip)
        guard options.contains(candidate), !populated.contains(candidate) else {
            return nil
        }
        return candidate
    }

    private func applyInitialDayIfNeeded(_ snapshot: TripsTimelineSnapshot) {
        guard !didApplyInitialDay else { return }
        guard let initial = snapshot.initialDate else {
            didApplyInitialDay = true
            return
        }
        guard dayOffsets[initial] != nil else { return }
        didApplyInitialDay = true
        selectedDate = initial
        jumpToDay(initial)
    }

    private func jumpToDay(_ date: LocalDate) {
        programmaticTarget = date
        if dayOffsets[date] != nil {
            performProgrammaticJump(to: date)
        } else {
            pendingJumpUntilLaidOut = date
        }
    }

    private func performProgrammaticJump(to date: LocalDate) {
        guard let minY = dayOffsets[date] else { return }
        scrollPosition.scrollTo(y: scrollOffsetY + (minY - dayJumpTopInset))
    }

    private func syncSelectedDate(with offsets: [LocalDate: CGFloat]) {
        if let target = programmaticTarget {
            if let offset = offsets[target], abs(offset - selectionAnchor) < 80 {
                programmaticTarget = nil
            }
            return
        }
        let current = TripsV2Formatting.selectedDate(from: offsets, pin: selectionAnchor)
        guard let current, selectedDate != current else { return }
        selectedDate = current
    }

    private func sectionAnchor(_ section: ItinerarySection) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: DayOffsetPreference.self,
                value: section.date.map { [$0: geometry.frame(in: .named(tripsScrollSpace)).minY] } ?? [:]
            )
        }
    }

    private func move(_ row: TimelineRow, in trip: Trip, offset: Int) {
        guard let destination = ItineraryDayComposer.moveDestination(
            of: row.id,
            offset: offset,
            in: trip,
            insertingEmptyDay: emptyDayToInsert(in: trip)
        ) else {
            return
        }
        Task {
            let from = destination.from
            let to = destination.to
            if let result = await session.processDetailed(.applyMutation(.moveTimelineItem(from: from, to: to))) {
                let receipt = result.receipt
                undoManager?.registerUndo(withTarget: session) { session in
                    Task { _ = await session.undo(receipt) }
                }
            }
        }
    }

    private func move(_ row: TimelineRow, in trip: Trip, to date: LocalDate?) {
        let item = row.id.item
        Task {
            if let result = await session.processDetailed(.applyMutation(.moveItemToDate(item, date))) {
                let receipt = result.receipt
                undoManager?.registerUndo(withTarget: session) { session in
                    Task { _ = await session.undo(receipt) }
                }
            }
        }
    }

    private func delete(_ row: TimelineRow, in trip: Trip) {
        let mutation: TripMutation
        switch row.id {
        case .leg(let id):
            mutation = .removeLeg(id)
        case .stay(let id, _):
            mutation = .removeStay(id)
        case .activity(let id):
            mutation = .removeActivity(id)
        }
        Task {
            if let result = await session.processDetailed(.applyMutation(mutation)) {
                let receipt = result.receipt
                undoManager?.registerUndo(withTarget: session) { session in
                    Task { _ = await session.undo(receipt) }
                }
            }
        }
    }

    private var dayJumpTopInset: CGFloat {
        dateChipBarHeight + 8
    }

    private var selectionAnchor: CGFloat {
        dateChipBarHeight + 24
    }
}

private let tripsScrollSpace = "trips-v2-scroll"
private let tripsTitleHideDistance: CGFloat = 64

private struct TripsNavigationSubtitle: ViewModifier {
    var text: String

    func body(content: Content) -> some View {
        content.navigationSubtitle(Text(verbatim: text))
    }
}

private struct DayOffsetPreference: PreferenceKey {
    static var defaultValue: [LocalDate: CGFloat] = [:]

    static func reduce(value: inout [LocalDate: CGFloat], nextValue: () -> [LocalDate: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

#if DEBUG
struct TripsV2PreviewRoot: View {
    @State private var router = AppRouter()
    @State private var session = TripSessionModel(
        previewState: .loaded,
        trip: TripsV2PreviewData.planningTrip
    )

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            TripsScreen()
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestination(route: route)
                }
        }
        .environment(router)
        .environment(session)
        .environment(\.locale, Locale(identifier: "ja"))
        .sheet(item: $router.presentation) { presentation in
            AppPresentationSheet(presentation: presentation, now: session.now)
                .environment(router)
                .environment(session)
                .environment(\.locale, Locale(identifier: "ja"))
        }
    }
}

enum TripsV2PreviewData {
    static let planningTrip: Trip = {
        do {
            return try makePlanningTrip()
        } catch {
            preconditionFailure("Failed to make Trips preview trip: \(error)")
        }
    }()

    private static func makePlanningTrip() throws -> Trip {
        let now = Date(timeIntervalSince1970: 1_788_393_600)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        var trip = try EmptyTripFactory.make(
            name: "Japan Trip",
            startDate: oct2,
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            preferredLanguage: "ja",
            now: now
        )
        let leg = try ItineraryItemFactory.makeLeg(
            origin: "東京",
            destination: "京都",
            scheduledAt: try ScheduledMoment(
                date: oct2,
                time: try LocalTime(hour: 10, minute: 3),
                timeZoneIdentifier: "Asia/Tokyo"
            ),
            at: now
        )
        let market = try ItineraryItemFactory.makeActivity(
            title: "錦市場",
            place: "京都",
            scheduledAt: try ScheduledMoment(date: oct2, timeZoneIdentifier: "Asia/Tokyo"),
            at: now
        )
        let stay = try ItineraryItemFactory.makeStay(
            place: "京都グランベルホテル",
            checkIn: try ScheduledMoment(
                date: oct2,
                time: try LocalTime(hour: 16, minute: 0),
                timeZoneIdentifier: "Asia/Tokyo"
            ),
            checkOut: try ScheduledMoment(
                date: try LocalDate(year: 2026, month: 10, day: 5),
                timeZoneIdentifier: "Asia/Tokyo"
            ),
            at: now
        )
        let fushimi = try ItineraryItemFactory.makeActivity(
            title: "伏見稲荷大社",
            place: "京都",
            scheduledAt: try ScheduledMoment(date: oct3, timeZoneIdentifier: "Asia/Tokyo"),
            at: now
        )
        let ramen = try ItineraryItemFactory.makeActivity(
            title: "京都ラーメン",
            place: "京都",
            scheduledAt: try ScheduledMoment(date: oct3, timeZoneIdentifier: "Asia/Tokyo"),
            at: now
        )
        var tea = try ItineraryItemFactory.makeActivity(
            title: "茶道体験",
            place: "京都",
            scheduledAt: try ScheduledMoment(
                date: oct3,
                time: try LocalTime(hour: 14, minute: 0),
                timeZoneIdentifier: "Asia/Tokyo"
            ),
            at: now
        )
        tea.reservation.status = try Slot.confirmed(value: .booked, source: .userStated, updatedAt: now)
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(
            .setTransportMode(leg.id, .shinkansen),
            to: trip,
            at: now
        )
        trip = try TripMutationApplier.apply(.addActivity(market, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(fushimi, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(ramen, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(tea, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(
            .setDaySubtitle(oct2, "京都に移動"),
            to: trip,
            at: now
        )
        return trip
    }
}

#Preview("TIME GUTTER") {
    TripsV2PreviewRoot()
}

#Preview("MIXED TIMING") {
    NavigationStack {
        TripsScreen()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: TripsV2PreviewData.planningTrip,
            clock: .fixed(try! LocalDate(year: 2026, month: 10, day: 3).date(in: TimeZone(identifier: "Asia/Tokyo")!)!)
        )
    )
    .environment(\.locale, Locale(identifier: "ja"))
}
#endif
