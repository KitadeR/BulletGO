import SwiftUI

struct ContextualHomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch session.loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityID.contextualHomeLoading)
            case .failed:
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
                .accessibilityIdentifier(AccessibilityID.contextualHomeFailed)
            case .empty:
                emptyState
            case .loaded:
                if let trip = session.trip {
                    loadedHome(trip)
                } else {
                    emptyState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "house")
                .font(.largeTitle)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .accessibilityHidden(true)
            Text("No trip yet")
                .font(DesignTokens.Typography.headline)
            Text("Create a trip to see what matters now, and keep the full itinerary in Trips.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .multilineTextAlignment(.center)
            Button("Create trip") {
                router.present(.createTrip)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.createTripButton)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.contextualHomeEmpty)
    }

    private func loadedHome(_ trip: Trip) -> some View {
        let snapshot = ContextualHomeComposer.snapshot(
            for: trip,
            catalog: session.catalog,
            now: session.now
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                switch snapshot.tripPhase {
                case .planning, .beforeTrip:
                    preTripContent(snapshot)
                case .inTrip:
                    inTripContent(snapshot)
                case .finished:
                    finishedContent(snapshot)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(AccessibilityID.contextualHome)
        .animation(DesignTokens.Motion.content(reduceMotion), value: snapshot.tripPhase)
        .animation(DesignTokens.Motion.content(reduceMotion), value: snapshot.primaryNow?.id)
    }

    @ViewBuilder
    private func preTripContent(_ snapshot: ContextualHomeSnapshot) -> some View {
        HomeContextHeader(
            title: countryDisplay(snapshot.place.country),
            subtitle: countdownText(snapshot.daysUntilStart).map(DisplayText.localized),
            tripName: snapshot.tripName,
            datesText: snapshot.tripDatesText,
            destinations: snapshot.destinations
        )

        if let item = snapshot.primaryNow {
            primaryNowSection(item, heading: "Next to prepare")
        } else {
            arrangeTripsPrompt()
        }
    }

    @ViewBuilder
    private func inTripContent(_ snapshot: ContextualHomeSnapshot) -> some View {
        HomeContextHeader(
            title: snapshot.place.city.map(DisplayText.verbatim) ?? countryDisplay(snapshot.place.country),
            subtitle: snapshot.place.city == nil ? nil : countryDisplay(snapshot.place.country),
            tripName: snapshot.tripName,
            datesText: nil,
            destinations: []
        )

        if let item = snapshot.primaryNow {
            primaryNowSection(item, heading: "Now")
        } else {
            arrangeTripsPrompt()
        }

        if !snapshot.todayRows.isEmpty {
            HomeTodaySchedule(rows: snapshot.todayRows) { destination in
                router.push(destination)
            }
        }
    }

    @ViewBuilder
    private func finishedContent(_ snapshot: ContextualHomeSnapshot) -> some View {
        HomeContextHeader(
            title: .verbatim(snapshot.tripName),
            subtitle: snapshot.tripDatesText.map(DisplayText.verbatim),
            tripName: nil,
            datesText: nil,
            destinations: snapshot.destinations
        )

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("This trip has finished.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            Button("Open in Trips") {
                router.showTrips()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.finishedOpenTrips)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    private func primaryNowSection(_ item: TimelineNowItem, heading: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(heading)
                .font(DesignTokens.Typography.headline)
                .padding(.horizontal, DesignTokens.Spacing.md)
            HomePrimaryNowCard(item: item, accessibilityID: AccessibilityID.primaryNow) {
                handlePrimary(item)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.nowSection)
    }

    private func arrangeTripsPrompt() -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Open Trips to arrange dates, places, and journeys.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            Button("Open Trips") {
                router.showTrips()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.homeOpenTrips)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    private func handlePrimary(_ item: TimelineNowItem) {
        switch item.kind {
        case .task:
            if let destination = HomePrimaryActionComposer.destination(for: item, trip: session.trip) {
                router.push(destination)
            }
        case .resume(let legID):
            guard let tripID = session.trip?.id else { return }
            let entry: GuidanceEntry = item.contentKey == HomePrimaryActionComposer.startSetupContentKey
                ? .compose
                : .resume
            router.present(.guidance(tripID, legID, entry, .showHome))
        }
    }

    private func countdownText(_ days: Int?) -> LocalizedStringResource? {
        guard let days else { return nil }
        if days == 1 {
            return LocalizedStringResource(
                "1 day to go",
                comment: "Countdown text for a single day remaining in a trip."
            )
        }
        return LocalizedStringResource(
            "\(days) days to go",
            comment: "A countdown text for a trip with multiple days. The argument is the number of days."
        )
    }

    private func countryDisplay(_ country: String) -> DisplayText {
        if country == ContextPlaceComposer.japanCountry {
            return .localized(
                LocalizedStringResource(
                    "Japan",
                    comment: "Country name shown on Home when the trip is in Japan."
                )
            )
        }
        return .verbatim(country)
    }
}

struct HomeContextHeader: View {
    var title: DisplayText
    var subtitle: DisplayText?
    var tripName: String?
    var datesText: String?
    var destinations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            DisplayTextLabel(text: title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                DisplayTextLabel(text: subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let tripName, !tripName.isEmpty {
                Text(verbatim: tripName)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let datesText, !datesText.isEmpty {
                Text(verbatim: datesText)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            }
            if !destinations.isEmpty {
                Text(verbatim: destinations.joined(separator: " · "))
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

struct HomePrimaryNowCard: View {
    var item: TimelineNowItem
    var accessibilityID: String?
    var action: () -> Void

    var body: some View {
        NowConcernCard(
            title: .localized(item.content.title),
            subtitle: item.content.subtitle.map(DisplayText.localized),
            systemImage: item.content.systemImage,
            accessibilityID: accessibilityID ?? identifier,
            action: action
        )
    }

    private var identifier: String {
        switch item.kind {
        case .task:
            AccessibilityID.nowTask(contentKey: item.contentKey)
        case .resume:
            item.contentKey == HomePrimaryActionComposer.startSetupContentKey
                ? AccessibilityID.startGuidance
                : AccessibilityID.resumeGuidance
        }
    }
}

struct HomeTodaySchedule: View {
    var rows: [TodayScheduleRow]
    var open: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Today’s schedule")
                .font(DesignTokens.Typography.headline)
                .padding(.horizontal, DesignTokens.Spacing.md)
            ForEach(rows) { item in
                Group {
                    if let destination = item.row.destination {
                        Button {
                            open(destination)
                        } label: {
                            scheduleRow(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.homeScheduleRow(item.id))
                    } else {
                        scheduleRow(item)
                            .accessibilityIdentifier(AccessibilityID.homeScheduleRow(item.id))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.todaySchedule)
    }

    private func scheduleRow(_ item: TodayScheduleRow) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Circle()
                .fill(stateColor(item.visualState))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.row.title)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .strikethrough(item.visualState == .completed)
                    .fixedSize(horizontal: false, vertical: true)
                DisplayTextLabel(text: item.row.subtitle)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
            if let timeLabel = item.timeLabel {
                Text(verbatim: timeLabel)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            }
        }
        .frame(minHeight: DesignTokens.TapTarget.minimum)
        .opacity(item.visualState == .completed ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private func stateColor(_ state: TodayScheduleVisualState) -> Color {
        switch state {
        case .completed:
            DesignTokens.Color.secondaryText
        case .current:
            DesignTokens.Color.now
        case .upcoming:
            DesignTokens.Color.remembered
        case .neutral:
            DesignTokens.Color.stroke
        }
    }
}

#if DEBUG
#Preview("Before trip") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.beforeTrip,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
}

#Preview("Planning") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.planning,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
}

#Preview("In trip") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.inTrip,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
}

#Preview("Finished") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.finished,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
}

#Preview("Empty") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .empty))
}

#Preview("Japanese") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.beforeTrip,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.inTrip,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.readyForNow,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
    .dynamicTypeSize(.accessibility3)
}
#endif
