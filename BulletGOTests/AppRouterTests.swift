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

    @Test func pushOperatesOnTheSelectedTabOnly() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        let homeRoute = AppRoute.taskDetail(trip.id, TaskID())
        router.selectedTab = .home
        router.push(homeRoute)
        router.selectedTab = .trips
        let tripsRoute = AppRoute.legDetail(trip.id, trip.legs[0].id)
        router.push(tripsRoute)
        #expect(router.homePath == [homeRoute])
        #expect(router.tripsPath == [tripsRoute])
        #expect(router.youPath.isEmpty)
        router.selectedTab = .home
        #expect(router.path == [homeRoute])
    }

    @Test func switchingTabsRestoresEachPath() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.selectedTab = .trips
        router.push(.legDetail(trip.id, trip.legs[0].id))
        router.selectedTab = .you
        router.push(.comingSoon(.appSettings))
        router.selectedTab = .trips
        #expect(router.path == [.legDetail(trip.id, trip.legs[0].id)])
        router.selectedTab = .you
        #expect(router.path == [.comingSoon(.appSettings)])
    }

    @Test func showHomeCanResetEveryTabPath() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.selectedTab = .trips
        router.push(.legDetail(trip.id, trip.legs[0].id))
        router.selectedTab = .home
        router.push(.taskDetail(trip.id, TaskID()))
        router.showHome(reset: true)
        #expect(router.selectedTab == .home)
        #expect(router.homePath.isEmpty)
        #expect(router.tripsPath.isEmpty)
        #expect(router.youPath.isEmpty)
    }

    @Test func globalSheetDoesNotUseTabPaths() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.selectedTab = .trips
        router.push(.legDetail(trip.id, trip.legs[0].id))
        router.present(.createTrip)
        #expect(router.tripsPath == [.legDetail(trip.id, trip.legs[0].id)])
        #expect(router.homePath.isEmpty)
        #expect(router.presentation == .createTrip)
        router.dismissPresentation()
        #expect(router.presentation == nil)
        #expect(router.tripsPath == [.legDetail(trip.id, trip.legs[0].id)])
    }

    @Test func presentsGuidanceSheetWithoutPushing() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let router = AppRouter()
        router.present(.guidance(trip.id, trip.legs[0].id, .compose, .showHome))
        #expect(router.path.isEmpty)
        #expect(router.presentation == .guidance(trip.id, trip.legs[0].id, .compose, .showHome))
        router.dismissPresentation()
        #expect(router.presentation == nil)
    }
}
