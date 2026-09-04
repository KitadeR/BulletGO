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
        HomeContextHero(
            title: countryDisplay(snapshot.place.country),
            subtitle: countdownText(snapshot.daysUntilStart).map(DisplayText.localized),
            detail: .verbatim(snapshot.tripName),
            city: nil
        )
        .padding(.horizontal, DesignTokens.Spacing.md)

        if !snapshot.destinations.isEmpty || snapshot.tripDatesText != nil {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(snapshot.tripName)
                    .font(DesignTokens.Typography.headline)
                if let dates = snapshot.tripDatesText {
                    Text(verbatim: dates)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
                if !snapshot.destinations.isEmpty {
                    Text(verbatim: snapshot.destinations.joined(separator: " · "))
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }

        if let item = snapshot.primaryNow {
            primaryNowSection(item, heading: "Next to prepare")
        }

        if !snapshot.preparationItems.isEmpty {
            HomePreparationOverview(items: snapshot.preparationItems) { destination in
                router.push(destination)
            }
        }

        if !snapshot.upcomingRows.isEmpty {
            HomeTodaySchedule(
                title: LocalizedStringResource("Coming itinerary", comment: "Home section for the next dated itinerary before the trip starts."),
                rows: snapshot.upcomingRows.map {
                    TodayScheduleRow(row: $0, visualState: $0.isCurrent ? .current : .neutral, timeLabel: nil)
                }
            ) { destination in
                router.push(destination)
            }
        }
    }

    @ViewBuilder
    private func inTripContent(_ snapshot: ContextualHomeSnapshot) -> some View {
        HomeContextHero(
            title: snapshot.place.city.map(DisplayText.verbatim) ?? countryDisplay(snapshot.place.country),
            subtitle: snapshot.place.city == nil ? nil : countryDisplay(snapshot.place.country),
            detail: .verbatim(snapshot.tripName),
            city: snapshot.place.city
        )
        .padding(.horizontal, DesignTokens.Spacing.md)

        if let item = snapshot.primaryNow {
            primaryNowSection(item, heading: "Now")
        }

        if !snapshot.todayRows.isEmpty {
            HomeTodaySchedule(
                title: LocalizedStringResource("Today’s schedule", comment: "Home section for today’s itinerary items."),
                rows: snapshot.todayRows
            ) { destination in
                router.push(destination)
            }
        }
    }

    @ViewBuilder
    private func finishedContent(_ snapshot: ContextualHomeSnapshot) -> some View {
        HomeContextHero(
            title: .verbatim(snapshot.tripName),
            subtitle: snapshot.tripDatesText.map(DisplayText.verbatim),
            detail: snapshot.destinations.isEmpty
                ? nil
                : .verbatim(snapshot.destinations.joined(separator: " · ")),
            city: nil
        )
        .padding(.horizontal, DesignTokens.Spacing.md)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("This trip has finished.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            Button("Open in Trips") {
                router.showTrips()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.finishedOpenTrips)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    private func primaryNowSection(_ item: TimelineNowItem, heading: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(heading)
                .font(DesignTokens.Typography.headline)
                .padding(.horizontal, DesignTokens.Spacing.md)
            HomePrimaryNowCard(item: item) {
                handlePrimary(item)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.nowSection)
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

struct HomeContextHero: View {
    var title: DisplayText
    var subtitle: DisplayText?
    var detail: DisplayText?
    var city: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JourneyArtwork(kind: .japanMap)
                .allowsHitTesting(false)
            LinearGradient(
                colors: [.clear, DesignTokens.Color.canvas.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                DisplayTextLabel(text: title)
                    .font(DesignTokens.Typography.display)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if showsCity, let city {
                    Text(verbatim: city)
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Color.primaryText)
                }
                if let subtitle, !isEmpty(subtitle) {
                    DisplayTextLabel(text: subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
                if let detail, !isEmpty(detail) {
                    DisplayTextLabel(text: detail)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var showsCity: Bool {
        guard let city, !city.isEmpty else { return false }
        if case .verbatim(let titleValue) = title, titleValue == city {
            return false
        }
        return true
    }

    private func isEmpty(_ text: DisplayText) -> Bool {
        if case .verbatim(let value) = text {
            return value.isEmpty
        }
        return false
    }
}

struct HomePrimaryNowCard: View {
    var item: TimelineNowItem
    var action: () -> Void

    var body: some View {
        NowConcernCard(
            title: .localized(item.content.title),
            subtitle: item.content.subtitle.map(DisplayText.localized),
            systemImage: item.content.systemImage,
            accessibilityID: identifier,
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

struct HomePreparationOverview: View {
    var items: [PreparationOverviewItem]
    var open: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Trip readiness")
                .font(DesignTokens.Typography.headline)
                .padding(.horizontal, DesignTokens.Spacing.md)
            ForEach(items) { item in
                QuietComingUpRow(
                    title: .verbatim(item.title),
                    subtitle: .localized(statusText(item)),
                    systemImage: "checklist",
                    showsChevron: item.destination != nil,
                    accessibilityID: AccessibilityID.preparationOverview,
                    action: {
                        if let destination = item.destination {
                            open(destination)
                        }
                    }
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.preparationOverview)
    }

    private func statusText(_ item: PreparationOverviewItem) -> LocalizedStringResource {
        switch (item.bookingStatus, item.readinessStatus) {
        case (.booked, .ready):
            LocalizedStringResource("Booked · Ready", comment: "Preparation row when booking is booked and a readiness check is ready.")
        case (.booked, _):
            LocalizedStringResource("Booked · Unverified", comment: "Preparation row when a reservation is booked but readiness is not proven.")
        case (.notBooked, .needsDetail):
            LocalizedStringResource("Not booked · Detail needed", comment: "Preparation row when booking is missing and more detail is required.")
        case (.notBooked, .actionRequired):
            LocalizedStringResource("Not booked · Action needed", comment: "Preparation row when booking is missing and a readiness check needs action.")
        case (_, .needsDetail):
            LocalizedStringResource("Detail needed", comment: "Preparation row when more information is required.")
        case (_, .actionRequired):
            LocalizedStringResource("Action needed", comment: "Preparation row when a readiness check needs action.")
        case (.notBooked, _):
            LocalizedStringResource("Not booked · Unverified", comment: "Preparation row when booking is not made and readiness is unverified.")
        default:
            LocalizedStringResource("Unverified", comment: "Preparation row when there is no readiness check yet.")
        }
    }
}

struct HomeTodaySchedule: View {
    var title: LocalizedStringResource
    var rows: [TodayScheduleRow]
    var open: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
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
                    } else {
                        scheduleRow(item)
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
                    .strikethrough(item.visualState == .completed)
                DisplayTextLabel(text: item.row.subtitle)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
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
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.beforeTrip))
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
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.beforeTrip))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .dynamicTypeSize(.accessibility3)
}
#endif
