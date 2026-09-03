import Testing
@testable import BulletGO

@MainActor
struct AppRouterTests {
    @Test func pushAppendsRoute() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        let route = AppRoute.legDetail(trip.id, trip.legs[0].id)
        router.push(route)
        #expect(router.path == [route])
    }

    @Test func popRemovesLastRoute() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.push(.legDetail(trip.id, trip.legs[0].id))
        router.push(.comingSoon(.bookingMethod))
        router.pop()
        #expect(router.path == [.legDetail(trip.id, trip.legs[0].id)])
    }

    @Test func popOnEmptyPathIsNoOp() {
        let router = AppRouter()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test func popToRootClearsPath() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.push(.taskDetail(trip.id, TaskID()))
        router.push(.comingSoon(.bookingMethod))
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test func pushLegDetailUsesTripAndLegIDs() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        let route = AppRoute.legDetail(trip.id, trip.legs[0].id)
        router.push(route)
        #expect(router.path == [route])
        #expect(AppRoute.legDetail(trip.id, trip.legs[1].id) != route)
    }

    @Test func presentsGuidanceSheetWithoutPushing() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.present(.guidance(trip.id, trip.legs[0].id, .compose))
        #expect(router.path.isEmpty)
        #expect(router.presentation == .guidance(trip.id, trip.legs[0].id, .compose))
        router.dismissPresentation()
        #expect(router.presentation == nil)
    }
}
