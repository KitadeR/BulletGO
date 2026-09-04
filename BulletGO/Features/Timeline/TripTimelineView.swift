import SwiftUI

struct TripTimelineView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        router.present(.addItineraryItem(trip.id))
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
        let sections = ItineraryDayComposer.sections(for: trip)
        let focusKind = trip.focusLegID.flatMap { id in trip.legs.first { $0.id == id } }
            .map(JourneyVisualProvider.kind(for:)) ?? .generic

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                JourneyHero(
                    title: trip.name.value ?? "",
                    subtitle: TripContentResolver.tripDatesText(trip),
                    kind: focusKind
                )
                .padding(.horizontal, DesignTokens.Spacing.md)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(section.title)
                                .font(DesignTokens.Typography.headline)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                            ForEach(section.rows) { row in
                                timelineRow(row, trip: trip)
                                    .padding(.horizontal, DesignTokens.Spacing.md)
                            }
                        }
                        .accessibilityIdentifier(
                            section.id == .unscheduled && section.title == String(localized: "Unscheduled")
                                ? AccessibilityID.itineraryUnscheduled
                                : AccessibilityID.routeRail
                        )
                    }
                }
                .accessibilityIdentifier(AccessibilityID.routeRail)
            }
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(AccessibilityID.tripTimeline)
        .animation(DesignTokens.Motion.content(reduceMotion), value: sections.count)
    }

    @ViewBuilder
    private func timelineRow(_ row: TimelineRow, trip: Trip) -> some View {
        Group {
            if let destination = row.destination {
                NavigationLink(value: destination) {
                    RouteRailRow(
                        title: row.title,
                        subtitle: row.subtitle,
                        kind: row.visualKind,
                        isCurrent: row.isCurrent,
                        isLeg: row.isLeg,
                        accessibilityID: timelineIdentifier(row),
                        action: nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(timelineIdentifier(row))
            } else {
                RouteRailRow(
                    title: row.title,
                    subtitle: row.subtitle,
                    kind: row.visualKind,
                    isCurrent: row.isCurrent,
                    isLeg: row.isLeg,
                    accessibilityID: timelineIdentifier(row),
                    action: nil
                )
            }
        }
        .modifier(SelectedTrait(isSelected: row.isCurrent))
        .contextMenu {
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
            if case .stay(let id) = row.id {
                Button("Move to Unscheduled") {
                    Task { _ = await session.process(.applyMutation(.unscheduleStay(id))) }
                }
            }
        }
        .accessibilityAction(named: Text("Move up")) { move(row, in: trip, offset: -1) }
        .accessibilityAction(named: Text("Move down")) { move(row, in: trip, offset: 1) }
    }

    private func move(_ row: TimelineRow, in trip: Trip, offset: Int) {
        guard let from = trip.timeline.firstIndex(where: { item in
            switch (item, row.id) {
            case (.leg(let id), .leg(let other)): id == other
            case (.stay(let id), .stay(let other)): id == other
            case (.activity(let id), .activity(let other)): id == other
            default: false
            }
        }) else { return }
        let to = offset > 0 ? from + offset + 1 : from + offset
        guard to >= 0, to <= trip.timeline.count else { return }
        Task { _ = await session.process(.applyMutation(.moveTimelineItem(from: from, to: to))) }
    }

    private func timelineIdentifier(_ row: TimelineRow) -> String {
        switch row.id {
        case .leg(let id):
            AccessibilityID.timelineLeg(id)
        case .stay(let id):
            AccessibilityID.timelineStay(id)
        case .activity(let id):
            AccessibilityID.timelineActivity(id)
        }
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

#Preview("Coming up") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
}

#Preview("Ready now") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
}

#Preview("Japanese") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
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
