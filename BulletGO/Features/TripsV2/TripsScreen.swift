import SwiftUI

struct TripsScreen: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(\.locale) private var locale

    @State private var selectedDate: LocalDate?
    @State private var programmaticTarget: LocalDate?
    @State private var didApplyInitialDay = false

    var body: some View {
        Group {
            switch session.loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn’t load your trip", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        Task { await session.retry() }
                    }
                }
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
        .toolbarVisibility(.hidden, for: .navigationBar)
        .accessibilityIdentifier(AccessibilityID.tripsV2Screen)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Your trip will appear here")
                .font(DesignTokens.Typography.headline)
            Text("Create a trip to start arranging dates, places, and journeys.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.tripTimelineEmpty)
    }

    private func loadedTimeline(_ trip: Trip) -> some View {
        let snapshot = ItineraryDayComposer.snapshot(for: trip, now: session.now)
        return VStack(alignment: .leading, spacing: 16) {
            TripsV2Header(
                destinations: TripsV2Formatting.destinations(in: trip),
                datesText: TripsV2Formatting.dateRange(for: trip, locale: locale)
            )
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
                            TripsDaySection(section: section, locale: locale)
                                .id(ItineraryDayComposer.scrollAnchor(for: section))
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
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

    private func applyInitialDayIfNeeded(_ snapshot: TripsTimelineSnapshot, proxy: ScrollViewProxy) {
        guard !didApplyInitialDay else { return }
        didApplyInitialDay = true
        guard let initial = snapshot.initialDate else { return }
        selectedDate = initial
        programmaticTarget = initial
        proxy.scrollTo(ItineraryDayComposer.scrollAnchor(for: initial), anchor: .top)
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
        NavigationStack {
            TripsScreen()
        }
        .environment(router)
        .environment(session)
        .environment(\.locale, Locale(identifier: "ja"))
    }
}

enum TripsV2PreviewData {
    static let planningTrip: Trip = {
        do {
            return try makePlanningTrip()
        } catch {
            preconditionFailure("Failed to make TripsV2 preview trip: \(error)")
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
        let tea = try ItineraryItemFactory.makeActivity(
            title: "茶道体験",
            place: "京都",
            scheduledAt: try ScheduledMoment(
                date: oct3,
                time: try LocalTime(hour: 14, minute: 0),
                timeZoneIdentifier: "Asia/Tokyo"
            ),
            at: now
        )
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: now)
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
