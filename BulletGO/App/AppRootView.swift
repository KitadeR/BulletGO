import SwiftUI

struct AppRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.featureRegistry) private var registry

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            TripTimelineView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .featureHub:
                        FeatureHubView()
                    case .comingSoon(let feature):
                        ComingSoonView(feature: feature, registry: registry)
                    case .legDetail(let tripID, let legID):
                        LegDetailView(tripID: tripID, legID: legID)
                    }
                }
        }
    }
}

#if DEBUG
#Preview("English") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Japanese") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
        .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
        .dynamicTypeSize(.accessibility3)
}
#endif
