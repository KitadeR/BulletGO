import SwiftUI

struct AppRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    ContextualHomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            AppRouteDestination(route: route)
                        }
                }
            }
            .accessibilityIdentifier(AccessibilityID.homeTab)

            Tab(AppTab.trips.title, systemImage: AppTab.trips.systemImage, value: AppTab.trips) {
                NavigationStack(path: $router.tripsPath) {
                    TripsScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            AppRouteDestination(route: route)
                        }
                }
            }
            .accessibilityIdentifier(AccessibilityID.tripsTab)

            Tab(AppTab.you.title, systemImage: AppTab.you.systemImage, value: AppTab.you) {
                NavigationStack(path: $router.youPath) {
                    YouView()
                        .navigationDestination(for: AppRoute.self) { route in
                            AppRouteDestination(route: route)
                        }
                }
            }
            .accessibilityIdentifier(AccessibilityID.youTab)
        }
        .sheet(item: $router.presentation) { presentation in
            AppPresentationSheet(presentation: presentation, now: session.now)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await session.load(showLoading: false)
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
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.inTrip))
        .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
        .dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    AppRootView()
        .environment(AppRouter())
        .environment(TripSessionModel(previewState: .empty))
}
#endif
