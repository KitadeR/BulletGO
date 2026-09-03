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
        .navigationTitle(session.trip?.name.value ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(AccessibilityID.tripTimelineLoading)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your trip will appear here", systemImage: "map")
        } description: {
            Text("When a trip is added, you’ll see the whole journey here.")
        }
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
        let nowItems = TimelineNowComposer.items(for: trip, catalog: session.catalog)
        let nextItems = TimelineNextComposer.items(for: trip)
        let rows = TimelineRowComposer.rows(for: trip)
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

                if !nowItems.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("What matters now")
                            .font(DesignTokens.Typography.headline)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        ForEach(nowItems) { item in
                            nowRow(item)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.nowSection)
                }

                if !nextItems.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Coming up")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        ForEach(nextItems) { item in
                            comingUpRow(item)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.comingUpSection)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Journey")
                        .font(DesignTokens.Typography.headline)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    ForEach(rows) { row in
                        timelineRow(row)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityID.routeRail)
            }
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(AccessibilityID.tripTimeline)
        .animation(DesignTokens.Motion.content(reduceMotion), value: nowItems.count)
    }

    @ViewBuilder
    private func nowRow(_ item: TimelineNowItem) -> some View {
        switch item.kind {
        case .task:
            NowConcernCard(
                title: .localized(item.content.title),
                subtitle: item.content.subtitle.map(DisplayText.localized),
                systemImage: item.content.systemImage,
                accessibilityID: nowIdentifier(item),
                action: {
                    if let destination = item.destination {
                        router.push(destination)
                    }
                }
            )
        case .resume(let legID):
            NowConcernCard(
                title: .localized(item.content.title),
                subtitle: item.content.subtitle.map(DisplayText.localized),
                systemImage: item.content.systemImage,
                accessibilityID: AccessibilityID.resumeGuidance,
                action: {
                    guard let tripID = session.trip?.id else { return }
                    router.present(.guidance(tripID, legID, .resume))
                }
            )
        }
    }

    @ViewBuilder
    private func comingUpRow(_ item: TimelineNextItem) -> some View {
        QuietComingUpRow(
            title: .localized(item.content.title),
            subtitle: item.content.subtitle.map(DisplayText.localized),
            systemImage: item.content.systemImage,
            showsChevron: item.destination != nil,
            accessibilityID: comingUpIdentifier(item),
            action: {
                if let destination = item.destination {
                    router.push(destination)
                }
            }
        )
    }

    @ViewBuilder
    private func timelineRow(_ row: TimelineRow) -> some View {
        RouteRailRow(
            title: row.title,
            subtitle: row.subtitle,
            kind: row.visualKind,
            isCurrent: row.isCurrent,
            isLeg: row.isLeg,
            accessibilityID: timelineIdentifier(row),
            action: {
                if let destination = row.destination {
                    router.push(destination)
                }
            }
        )
        .modifier(SelectedTrait(isSelected: row.isCurrent))
    }

    private func nowIdentifier(_ item: TimelineNowItem) -> String {
        switch item.kind {
        case .task:
            AccessibilityID.nowTask(contentKey: item.contentKey)
        case .resume:
            AccessibilityID.resumeGuidance
        }
    }

    private func comingUpIdentifier(_ item: TimelineNextItem) -> String {
        switch item.kind {
        case .task(let id):
            AccessibilityID.comingUpTask(id)
        case .remembered(let remembered):
            AccessibilityID.comingUpRemembered(contentKey: remembered.contentKey, scope: remembered.scope)
        }
    }

    private func timelineIdentifier(_ row: TimelineRow) -> String {
        switch row.id {
        case .leg(let id):
            AccessibilityID.timelineLeg(id)
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
