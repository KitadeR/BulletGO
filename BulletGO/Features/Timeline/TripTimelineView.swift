import SwiftUI

struct TripTimelineView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session

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
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Features", systemImage: "square.grid.2x2") {
                    router.push(.featureHub)
                }
                .accessibilityIdentifier(AccessibilityID.openFeatureHub)
            }
        }
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(AccessibilityID.tripTimelineLoading)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                "Your trip will appear here",
                systemImage: "map"
            )
        } description: {
            Text("When a trip is added, you’ll see the whole journey here.")
        }
        .accessibilityIdentifier(AccessibilityID.tripTimelineEmpty)
    }

    private var failedState: some View {
        ContentUnavailableView {
            Label(
                "Couldn’t load your trip",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Retry") {
                Task {
                    await session.retry()
                }
            }
            .accessibilityIdentifier(AccessibilityID.tripTimelineRetry)
        }
        .accessibilityIdentifier(AccessibilityID.tripTimelineFailed)
    }

    private func loadedTimeline(_ trip: Trip) -> some View {
        let nextItems = TimelineNextComposer.items(for: trip)
        let rows = TimelineRowComposer.rows(for: trip)
        return List {
            if !nextItems.isEmpty {
                Section {
                    ForEach(nextItems) { item in
                        comingUpRow(item)
                    }
                } header: {
                    Text("Coming up")
                }
                .accessibilityIdentifier(AccessibilityID.comingUpSection)
            }

            Section {
                ForEach(rows) { row in
                    timelineRow(row)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(DesignTokens.Spacing.md)
        .accessibilityIdentifier(AccessibilityID.tripTimeline)
    }

    @ViewBuilder
    private func comingUpRow(_ item: TimelineNextItem) -> some View {
        let isRemembered = isRememberedItem(item)
        let row = TimelineCardRow(
            title: .localized(item.content.title),
            subtitle: item.content.subtitle.map(DisplayText.localized),
            systemImage: item.content.systemImage,
            kind: isRemembered ? .remembered : .standard,
            showsChevron: item.destination != nil
        )
        Group {
            if let destination = item.destination {
                Button {
                    router.push(destination)
                } label: {
                    row
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    Text("Shows details for this journey.")
                )
            } else {
                row
            }
        }
        .listRowInsets(timelineInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier(comingUpIdentifier(item))
    }

    @ViewBuilder
    private func timelineRow(_ row: TimelineRow) -> some View {
        let card = TimelineCardRow(
            title: .verbatim(row.title),
            subtitle: row.subtitle,
            systemImage: row.systemImage,
            kind: row.isCurrent ? .current : .standard,
            showsChevron: row.destination != nil
        )
        Group {
            if let destination = row.destination {
                Button {
                    router.push(destination)
                } label: {
                    card
                }
                .buttonStyle(.plain)
            } else {
                card
            }
        }
        .listRowInsets(timelineInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier(timelineIdentifier(row))
        .modifier(SelectedTrait(isSelected: row.isCurrent))
    }

    private var timelineInsets: EdgeInsets {
        EdgeInsets(
            top: DesignTokens.Spacing.xs,
            leading: DesignTokens.Spacing.md,
            bottom: DesignTokens.Spacing.xs,
            trailing: DesignTokens.Spacing.md
        )
    }

    private func isRememberedItem(_ item: TimelineNextItem) -> Bool {
        if case .remembered = item.kind {
            return true
        }
        return false
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

#Preview("Japanese") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
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
