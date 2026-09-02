import Testing
@testable import BulletGO

@MainActor
struct AppRouterTests {
    @Test func pushAppendsRoute() {
        let router = AppRouter()
        router.push(.featureHub)
        #expect(router.path == [.featureHub])
    }

    @Test func popRemovesLastRoute() {
        let router = AppRouter()
        router.push(.featureHub)
        router.push(.comingSoon(.baggageCheck))
        router.pop()
        #expect(router.path == [.featureHub])
    }

    @Test func popOnEmptyPathIsNoOp() {
        let router = AppRouter()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test func popToRootClearsPath() {
        let router = AppRouter()
        router.push(.featureHub)
        router.push(.comingSoon(.baggageCheck))
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}
