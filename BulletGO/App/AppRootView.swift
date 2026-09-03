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
                    case .comingSoon(let feature):
                        ComingSoonView(feature: feature, registry: registry)
                    case .legDetail(let tripID, let legID):
                        LegDetailView(tripID: tripID, legID: legID)
                    case .taskDetail(let tripID, let taskID):
                        TaskDetailView(tripID: tripID, taskID: taskID)
                    case .baggageCheck(let tripID, let legID, let taskID):
                        BaggageCheckView(tripID: tripID, legID: legID, taskID: taskID)
                    }
                }
        }
        .sheet(item: $router.presentation) { presentation in
            switch presentation {
            case .guidance(let tripID, let legID, let entry):
                GuidanceFlowView(tripID: tripID, legID: legID, entry: entry)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
        .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
        .dynamicTypeSize(.accessibility3)
}
#endif
