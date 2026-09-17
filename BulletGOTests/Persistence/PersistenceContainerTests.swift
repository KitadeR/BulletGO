import Foundation
import Testing
@testable import BulletGO

@MainActor
struct PersistenceContainerTests {
    @Test func inMemoryStoresAreIsolated() async throws {
        let first = try PersistenceStack.inMemory()
        let second = try PersistenceStack.inMemory()
        let trip = try DomainTestSupport.sampleTrip()

        try await first.repository.save(trip)

        #expect(try await first.repository.fetch(id: trip.id) == trip)
        #expect(try await second.repository.fetchAll().isEmpty)
    }

    @Test func diskStoreSurvivesContainerRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "BulletGO-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "BulletGO.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        var trip = try DomainTestSupport.sampleTrip()
        let later = DomainTestSupport.timestamp.addingTimeInterval(30)
        trip.name = try trip.name.updating(
            value: "Persisted Japan trip",
            status: .confirmed,
            source: .userConfirmed,
            confidence: .high,
            at: later
        )
        trip.updatedAt = later

        do {
            let stack = try PersistenceStack.onDisk(url: storeURL)
            try await stack.repository.save(trip)
            #expect(try await stack.repository.fetch(id: trip.id) == trip)
        }

        let reopened = try PersistenceStack.onDisk(url: storeURL)
        let loaded = try await reopened.repository.fetch(id: trip.id)
        #expect(loaded == trip)
        #expect(loaded?.name.revisions.count == 1)
    }

    @Test func bootstrapSeedsTheReferenceTrip() async throws {
        let stack = try PersistenceStack.inMemory()
        try await stack.bootstrap(seedReferenceTrip: true)
        try await stack.bootstrap(seedReferenceTrip: true)

        let trips = try await stack.repository.fetchAll()
        #expect(trips.count == 1)
        #expect(trips[0].id == ReferenceTripIdentity.trip)
        #expect(trips[0].legs.count == 3)
        #expect(trips[0].activities.count == 3)
    }

    @Test func emptyTripWithMappedActivitySurvivesRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "BulletGO-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "BulletGO.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = EngineTestSupport.now
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: now
        )
        let moment = try ScheduledMoment(date: oct3, timeZoneIdentifier: DomainTestSupport.timeZone)
        var activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kinkaku-ji",
            scheduledAt: moment,
            at: now
        )
        activity.placeReference = PlaceReference(
            provider: .appleMaps,
            providerID: "poi-kinkaku",
            name: "Kinkaku-ji",
            coordinate: GeoCoordinate(latitude: 35.0394, longitude: 135.7292),
            address: "1 Kinkakujicho, Kita-ku, Kyoto",
            category: "MKPOICategoryLandmark"
        )
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: now)

        do {
            let stack = try PersistenceStack.onDisk(url: storeURL)
            try await stack.repository.save(trip)
            #expect(try await stack.repository.fetch(id: trip.id) == trip)
        }

        let reopened = try PersistenceStack.onDisk(url: storeURL)
        let loaded = try await reopened.repository.fetch(id: trip.id)
        #expect(loaded?.activities.count == 1)
        #expect(loaded?.activities.first?.placeReference?.providerID == "poi-kinkaku")
        #expect(loaded?.activities.first?.placeReference?.provider == .appleMaps)
        #expect(loaded?.activities.first?.placeReference?.name == "Kinkaku-ji")
        #expect(loaded?.activities.first?.scheduledAt.value?.date == oct3)
        #expect(loaded?.timeline == [.activity(activity.id)])
    }

    @Test func bootstrapWithoutSeedLeavesStoreEmpty() async throws {
        let stack = try PersistenceStack.inMemory()
        try await stack.bootstrap()
        #expect(try await stack.repository.fetchAll().isEmpty)
    }
}
