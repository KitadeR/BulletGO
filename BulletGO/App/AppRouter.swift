import Foundation
import Observation

@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [AppRoute] = []
    var tripsPath: [AppRoute] = []
    var youPath: [AppRoute] = []
    var presentation: AppPresentation?

    var path: [AppRoute] {
        get { path(for: selectedTab) }
        set { setPath(newValue, for: selectedTab) }
    }

    func path(for tab: AppTab) -> [AppRoute] {
        switch tab {
        case .home: homePath
        case .trips: tripsPath
        case .you: youPath
        }
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        switch tab {
        case .home: homePath = path
        case .trips: tripsPath = path
        case .you: youPath = path
        }
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func present(_ presentation: AppPresentation) {
        self.presentation = presentation
    }

    func dismissPresentation() {
        presentation = nil
    }

    func showHome(reset: Bool) {
        if reset {
            homePath.removeAll()
            tripsPath.removeAll()
            youPath.removeAll()
        }
        selectedTab = .home
    }

    func showTrips(reset: Bool = false) {
        if reset {
            tripsPath.removeAll()
        }
        selectedTab = .trips
    }
}
