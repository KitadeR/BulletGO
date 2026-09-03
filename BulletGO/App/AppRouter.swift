import Foundation
import Observation

@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var presentation: AppPresentation?

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
}
