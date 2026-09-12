import SwiftUI

struct TripTimelineView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedDate: LocalDate?
    @State private var programmaticTarget: LocalDate?
    @State private var didApplyInitialDay = false

    var body: some View {
        Group {
            switch session.loadState {
            case .loading:
                loadingState
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
        .background(DesignTokens.Color.canvas)
        .navigationTitle(session.trip?.name.value ?? "BulletGO")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.loadState == .loaded, let trip = session.trip {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        router.present(.addItineraryItem(trip.id, initialDate: nil))
                    }
                    .accessibilityIdentifier(AccessibilityID.addItineraryButton)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add with AI") {
                        router.present(.itineraryTalk(trip.id, .trip))
                    }
                    .accessibilityIdentifier(AccessibilityID.talkAboutTrip)
                }
            }
        }
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(AccessibilityID.tripTimelineLoading)
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
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            TripsCompactHeader(title: snapshot.tripName, datesText: snapshot.tripDatesText)
            if !snapshot.dateOptions.isEmpty {
                TripsDateSelector(
                    options: snapshot.dateOptions,
                    selectedDate: selectedDate,
                    onSelect: { date in
                        selectedDate = date
                        programmaticTarget = date
                    }
                )
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        ForEach(snapshot.sections) { section in
                            daySection(section, trip: trip)
                                .id(ItineraryDayComposer.scrollAnchor(for: section))
                                .background {
                                    sectionAnchor(section)
                                }
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(.named(tripsScrollSpace))
                .onPreferenceChange(DayOffsetPreference.self) { offsets in
                    syncSelectedDate(with: offsets)
                }
                .accessibilityIdentifier(AccessibilityID.tripTimeline)
                .animation(DesignTokens.Motion.content(reduceMotion), value: snapshot.sections.count)
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
    }

    private func daySection(_ section: ItinerarySection, trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let date = section.date {
                TripsDayHeader(date: date)
                    .padding(.horizontal, DesignTokens.Spacing.md)
            } else {
                Text(section.title)
                    .font(DesignTokens.Typography.headline)
                    .padding(.horizontal, DesignTokens.Spacing.md)
            }

            if section.rows.isEmpty, let date = section.date {
                TripsEmptyDayState(
                    date: date,
                    addTitle: addTitle(for: date),
                    onAdd: { presentAdd(tripID: trip.id, date: date) }
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
            } else {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        if index > 0 {
                            TripTimelineConnector()
                        }
                        itemBlock(row, trip: trip)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            if let date = section.date, !section.rows.isEmpty {
                TripsDayAddButton(
                    date: date,
                    title: addTitle(for: date),
                    action: { presentAdd(tripID: trip.id, date: date) }
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(sectionIdentifier(section))
    }

    @ViewBuilder
    private func itemBlock(_ row: TimelineRow, trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            itemCard(row)
                .modifier(SelectedTrait(isSelected: row.isCurrent))
                .contextMenu { contextButtons(row, trip: trip) }
                .accessibilityAction(named: Text("Move up")) { move(row, in: trip, offset: -1) }
                .accessibilityAction(named: Text("Move down")) { move(row, in: trip, offset: 1) }

            if case .leg = row.id,
               let indication = TripsPreparationComposer.indication(for: row, trip: trip, catalog: session.catalog)
            {
                TripsPreparationRow(indication: indication) {
                    if let destination = indication.destination {
                        router.push(destination)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemCard(_ row: TimelineRow) -> some View {
        switch row.id {
        case .leg:
            linked(row) { TripLegCard(row: row) }
        case .stay:
            linked(row) { TripStayCard(row: row) }
        case .activity:
            linked(row) { TripActivityCard(row: row) }
        }
    }

    @ViewBuilder
    private func linked<Content: View>(_ row: TimelineRow, @ViewBuilder content: () -> Content) -> some View {
        if let destination = row.destination {
            NavigationLink(value: destination) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func contextButtons(_ row: TimelineRow, trip: Trip) -> some View {
        Button("Move up") { move(row, in: trip, offset: -1) }
        Button("Move down") { move(row, in: trip, offset: 1) }
        if case .leg(let id) = row.id {
            Button("Move to Unscheduled") {
                Task { _ = await session.process(.applyMutation(.unscheduleLeg(id))) }
            }
        }
        if case .activity(let id) = row.id {
            Button("Move to Unscheduled") {
                Task { _ = await session.process(.applyMutation(.unscheduleActivity(id))) }
            }
        }
        if case .stay(let id, _) = row.id {
            Button("Move to Unscheduled") {
                Task { _ = await session.process(.applyMutation(.unscheduleStay(id))) }
            }
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
        Task { _ = await session.process(.applyMutation(.moveTimelineItem(from: destination.from, to: destination.to))) }
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
        guard let candidate else {
            return nil
        }
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

    private func presentAdd(tripID: TripID, date: LocalDate) {
        router.present(.addItineraryItem(tripID, initialDate: date))
    }

    private func addTitle(for date: LocalDate) -> LocalizedStringResource {
        LocalizedStringResource(
            "Add to \(TripsDateFormatting.addDayLabel(date))",
            comment: "Button that opens add-to-trip with this day prefilled."
        )
    }

    private func sectionIdentifier(_ section: ItinerarySection) -> String {
        if let date = section.date {
            return AccessibilityID.tripsDaySection(date)
        }
        return AccessibilityID.itineraryUnscheduled
    }
}

private let tripsScrollSpace = "trips-scroll"
private let selectionAnchor: CGFloat = 140

private struct DayOffsetPreference: PreferenceKey {
    static var defaultValue: [LocalDate: CGFloat] = [:]

    static func reduce(value: inout [LocalDate: CGFloat], nextValue: () -> [LocalDate: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SelectedTrait: ViewModifier {
    var isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.accessibilityAddTraits(.isSelected)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Multi-day") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.multiDay))
}

#Preview("In trip today") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.multiDayInTrip,
            clock: .fixed(PreviewTrips.multiDayNow)
        )
    )
}

#Preview("Empty day today") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.multiDayInTrip,
            clock: .fixed(PreviewTrips.multiDayEmptyDayNow)
        )
    )
}

#Preview("Unscheduled") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Japanese") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.multiDay))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.multiDay))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.multiDay))
    .dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .empty))
}

#Preview("Failed") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .failed))
}
#endif
