import Foundation
@testable import BulletGO

enum EngineTestSupport {
    static let now = DomainTestSupport.timestamp

    final class FixtureToken {}

    static func catalog() throws -> QuestionCatalog {
        try QuestionCatalogLoader.loadProduction(from: .main)
    }

    static func pack() throws -> BaggagePolicyPack {
        try PackLoader.loadProduction(from: .main)
    }

    static func brain() throws -> TripBrain {
        TripBrain(catalog: try catalog(), pack: try pack(), clock: .fixed(now))
    }

    static func testBundle() -> Bundle {
        Bundle(for: FixtureToken.self)
    }

    static func moment(_ date: LocalDate) throws -> ScheduledMoment {
        try ScheduledMoment(date: date, timeZoneIdentifier: DomainTestSupport.timeZone)
    }
}

actor InMemoryTripRepository: TripRepository {
    private var storage: [TripID: Trip] = [:]
    private(set) var saveCount = 0

    func fetchAll() async throws -> [Trip] {
        Array(storage.values)
    }

    func fetch(id: TripID) async throws -> Trip? {
        storage[id]
    }

    func save(_ trip: Trip) async throws {
        saveCount += 1
        storage[trip.id] = trip
    }

    func delete(id: TripID) async throws {
        storage[id] = nil
    }
}

actor FailingTripRepository: TripRepository {
    func fetchAll() async throws -> [Trip] {
        throw EngineError.tripNotFound
    }

    func fetch(id: TripID) async throws -> Trip? {
        throw EngineError.tripNotFound
    }

    func save(_ trip: Trip) async throws {}

    func delete(id: TripID) async throws {}
}

actor SaveFailingTripRepository: TripRepository {
    private let trip: Trip

    init(trip: Trip) {
        self.trip = trip
    }

    func fetchAll() async throws -> [Trip] {
        [trip]
    }

    func fetch(id: TripID) async throws -> Trip? {
        trip
    }

    func save(_ trip: Trip) async throws {
        throw EngineError.tripNotFound
    }

    func delete(id: TripID) async throws {}
}
