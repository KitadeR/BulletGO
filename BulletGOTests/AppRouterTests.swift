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

    @Test func pushLegDetailUsesTripAndLegIDs() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        let route = AppRoute.legDetail(trip.id, trip.legs[0].id)
        router.push(route)
        #expect(router.path == [route])
        #expect(route != .featureHub)
        #expect(AppRoute.legDetail(trip.id, trip.legs[1].id) != route)
    }
}
