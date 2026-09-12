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
        .navigationTitle(session.trip?.name.value ?? "BulletGO")
        .navigationBarTitleDisplayMode(.inline)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.tripTimeline)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if session.loadState == .loaded, let trip = session.trip {
            ToolbarItem(placement: .topBarLeading) {
                Button("Add with AI") {
                    router.present(.itineraryTalk(trip.id, .trip))
                }
                .accessibilityIdentifier(AccessibilityID.talkAboutTrip)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add") {
                    router.present(.addItineraryItem(trip.id, initialDate: selectedDate))
                }
                .accessibilityIdentifier(AccessibilityID.addItineraryButton)
            }
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
        return VStack(alignment: .leading, spacing: 16) {
            Button {
                router.present(.switchTrip)
            } label: {
                TripsV2Header(
                    destinations: TripsV2Formatting.destinations(in: trip).isEmpty
                        ? (trip.name.value ?? "")
                        : TripsV2Formatting.destinations(in: trip),
                    datesText: TripsV2Formatting.dateRange(for: trip, locale: locale)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Switch trip"))
            if !snapshot.dateOptions.isEmpty {
                TripsDateStrip(
                    options: snapshot.dateOptions,
                    selectedDate: selectedDate,
                    locale: locale,
                    onSelect: { date in
                        selectedDate = date
                        programmaticTarget = date
                    }
                )
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(snapshot.sections) { section in
                            TripsDaySection(
                                section: section,
                                trip: trip,
                                catalog: session.catalog,
                                locale: locale,
                                onAdd: { date in
                                    router.present(.addItineraryItem(trip.id, initialDate: date))
                                },
                                onMove: { row, offset in
                                    move(row, in: trip, offset: offset)
                                },
                                onMoveToDate: { row, date in
                                    move(row, in: trip, to: date)
                                },
                                onDelete: { row in
                                    delete(row, in: trip)
                                }
                            )
                            .id(ItineraryDayComposer.scrollAnchor(for: section))
                            .background {
                                sectionAnchor(section)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 88)
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(.named(tripsScrollSpace))
                .onPreferenceChange(DayOffsetPreference.self) { offsets in
                    syncSelectedDate(with: offsets)
                }
                .accessibilityIdentifier(AccessibilityID.tripTimeline)
                .onAppear {
                    applyInitialDayIfNeeded(snapshot, proxy: proxy)
                }
                .onChange(of: programmaticTarget) { _, target in
                    guard let target else { return }
                    proxy.scrollTo(ItineraryDayComposer.scrollAnchor(for: target), anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        }
    }

    private func presentGuidedAdd(tripID: TripID, action: TripsFloatingAddAction) {
        let kind: ItineraryAddKind
        switch action {
        case .activity: kind = .activity
        case .leg: kind = .travel
        case .stay: kind = .stay
        }
        router.present(.guidedAdd(tripID, kind, initialDate: selectedDate, seedPlace: nil))
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

    private func applyInitialDayIfNeeded(_ snapshot: TripsTimelineSnapshot, proxy: ScrollViewProxy) {
        guard !didApplyInitialDay else { return }
        didApplyInitialDay = true
        guard let initial = snapshot.initialDate else { return }
        selectedDate = initial
        programmaticTarget = initial
        proxy.scrollTo(ItineraryDayComposer.scrollAnchor(for: initial), anchor: .top)
    }

    private func syncSelectedDate(with offsets: [LocalDate: CGFloat]) {
        if let target = programmaticTarget {
            if let offset = offsets[target], abs(offset - selectionAnchor) < 48 {
                programmaticTarget = nil
            }
            return
        }
        let visible = offsets.filter { $0.value <= selectionAnchor }
        guard let current = visible.max(by: { $0.value < $1.value })?.key else {
            return
        }
        if selectedDate != current {
            selectedDate = current
        }
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
            if await session.process(.applyMutation(.moveTimelineItem(from: from, to: to))) != nil {
                undoManager?.registerUndo(withTarget: session) { session in
                    Task {
                        _ = await session.process(.applyMutation(.moveTimelineItem(from: to, to: from)))
                    }
                }
            }
        }
    }

    private func move(_ row: TimelineRow, in trip: Trip, to date: LocalDate?) {
        let item = row.id.item
        let previous = trip.assignmentDate(for: item)
        Task {
            if await session.process(.applyMutation(.moveItemToDate(item, date))) != nil {
                undoManager?.registerUndo(withTarget: session) { session in
                    Task {
                        _ = await session.process(.applyMutation(.moveItemToDate(item, previous)))
                    }
                }
            }
        }
    }

    private func delete(_ row: TimelineRow, in trip: Trip) {
        let mutation: TripMutation
        let restore: TripMutation?
        switch row.id {
        case .leg(let id):
            mutation = .removeLeg(id)
            restore = trip.legs.first { $0.id == id }.map { .addLeg($0, atTimelineIndex: nil) }
        case .stay(let id, _):
            mutation = .removeStay(id)
            restore = trip.stays.first { $0.id == id }.map { .addStay($0, atTimelineIndex: nil) }
        case .activity(let id):
            mutation = .removeActivity(id)
            restore = trip.activities.first { $0.id == id }.map { .addActivity($0, atTimelineIndex: nil) }
        }
        Task {
            if await session.process(.applyMutation(mutation)) != nil, let restore {
                undoManager?.registerUndo(withTarget: session) { session in
                    Task { _ = await session.process(.applyMutation(restore)) }
                }
            }
        }
    }
}

private let tripsScrollSpace = "trips-v2-scroll"
private let selectionAnchor: CGFloat = 140

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
