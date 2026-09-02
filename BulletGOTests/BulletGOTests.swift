import Testing
@testable import BulletGO

@MainActor
struct BulletGOTests {
    @Test func productionRegistryLoads() {
        #expect(!FeatureRegistry.production.registrations.isEmpty)
    }
}
