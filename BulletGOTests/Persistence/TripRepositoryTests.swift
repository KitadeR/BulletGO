import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripRepositoryTests {
    @Test func saveFetchUpdateAndDeleteRoundTrip() async throws {
        let stack = try PersistenceStack.inMemory()
        let repository = stack.repository
        var trip = try DomainTestSupport.sampleTrip()

        try await repository.save(trip)
        let loaded = try await repository.fetch(id: trip.id)
        #expect(loaded == trip)

        let later = DomainTestSupport.timestamp.addingTimeInterval(120)
        trip.name = try trip.name.updating(
            value: "Updated Japan trip",
            status: .confirmed,
            source: .userConfirmed,
            confidence: .high,
            at: later
        )
        trip.updatedAt = later
        try await repository.save(trip)

        let all = try await repository.fetchAll()
        #expect(all.count == 1)
        #expect(all[0] == trip)
        #expect(all[0].name.revisions.count == 1)

        try await repository.delete(id: trip.id)
        #expect(try await repository.fetch(id: trip.id) == nil)
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test func saveUpsertsWithoutDuplicatingTripID() async throws {
        let repository = try PersistenceStack.inMemory().repository
        let first = try DomainTestSupport.sampleTrip()
        var second = first
        second.name = try Slot.confirmed(
            value: "Same ID",
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp.addingTimeInterval(5)
        )

        try await repository.save(first)
        try await repository.save(second)

        let all = try await repository.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].id == first.id)
        #expect(all[0].name.value == "Same ID")
    }

    @Test func saveStoresMultipleTrips() async throws {
        let repository = try PersistenceStack.inMemory().repository
        let first = try DomainTestSupport.sampleTrip()
        let second = try DomainTestSupport.sampleTrip()

        try await repository.save(first)
        try await repository.save(second)

        let all = try await repository.fetchAll()
        #expect(Set(all.map(\.id)) == [first.id, second.id])
    }

    @Test func saveRejectsInvalidAggregate() async throws {
        let repository = try PersistenceStack.inMemory().repository
        var trip = try DomainTestSupport.sampleTrip()
        trip.legs.append(trip.legs[0])

        await #expect(throws: PersistenceError.invalidAggregate(.duplicateLegIDs)) {
            try await repository.save(trip)
        }
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test func fetchRejectsUnsupportedPayloadVersion() async throws {
        let repository = try PersistenceStack.inMemory().repository
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        try await repository.updateRecord(id: trip.id, payloadVersion: 9)

        await #expect(throws: PersistenceError.unsupportedPayloadVersion(9)) {
            _ = try await repository.fetch(id: trip.id)
        }
    }

    @Test func fetchAllRejectsTripIDMismatch() async throws {
        let repository = try PersistenceStack.inMemory().repository
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        try await repository.updateRecord(id: trip.id, tripID: UUID())

        await #expect(throws: PersistenceError.tripIDMismatch) {
            _ = try await repository.fetchAll()
        }
    }
}
