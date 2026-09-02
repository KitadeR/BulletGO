import Foundation
import Testing
@testable import BulletGO

@MainActor
struct DomainCodableTests {
    @Test func sampleTripRoundTripsThroughJSON() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let data = try encoder.encode(trip)
        let decoded = try decoder.decode(Trip.self, from: data)
        #expect(decoded == trip)
        try decoded.validate()
        #expect(decoded.timeline.count == 6)
        #expect(decoded.legs.map(\.origin.value) == ["Tokyo", "Kyoto", "Osaka"])
        #expect(decoded.legs.map(\.destination.value) == ["Kyoto", "Osaka", "Hakata"])
    }

    @Test func changeEventRoundTrips() throws {
        let event = TripChangeEvent(
            id: ChangeEventID(),
            kind: .luggageAdded,
            target: .trip,
            changedPaths: [.bag(BagID(), .dimensions)],
            affectedFrom: try LocalDate(year: 2026, month: 10, day: 3),
            potentialScope: .futureLegs,
            impactLevel: .medium,
            createdAt: DomainTestSupport.timestamp
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(TripChangeEvent.self, from: encoder.encode(event))
        #expect(decoded == event)
    }
}
