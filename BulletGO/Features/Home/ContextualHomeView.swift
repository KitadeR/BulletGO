import SwiftUI

struct ContextualHomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session

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
                comingSoon(identifier: AccessibilityID.contextualHomeEmpty, showsCreateTrip: true)
            case .loaded:
                comingSoon(identifier: AccessibilityID.contextualHome, showsCreateTrip: session.trip == nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func comingSoon(identifier: String, showsCreateTrip: Bool) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ContentUnavailableView {
                Label("Coming soon", systemImage: "house")
            } description: {
                Text("Home is being rebuilt. Open Trips to arrange dates, places, and journeys.")
            }
            Button("Open Trips") {
                router.showTrips()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.homeOpenTrips)
            if showsCreateTrip {
                Button("Create trip") {
                    router.present(.createTrip)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.createTripButton)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
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

#if DEBUG
#Preview("Loaded") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
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
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        ContextualHomeView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.inTrip))
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
