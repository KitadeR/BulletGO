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
                    }
                }
        }
    }
}

#Preview("English") {
    AppRootView()
        .environment(AppRouter())
}

#Preview("Japanese") {
    AppRootView()
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    AppRootView()
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    AppRootView()
        .environment(AppRouter())
        .dynamicTypeSize(.accessibility3)
}
