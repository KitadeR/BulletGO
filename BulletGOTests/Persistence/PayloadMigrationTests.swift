import Foundation
import Testing
@testable import BulletGO

@MainActor
struct PayloadMigrationTests {
    @Test func v1UnknownReservationBecomesValuelessUnknownSlot() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let encoded = try v1Record(from: trip, statuses: ["unknown", "unknown", "unknown"])
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.id == trip.id)
        #expect(decoded.trip.schemaVersion == 4)
        #expect(decoded.rewritten?.payloadVersion == 4)
        #expect(decoded.rewritten?.domainSchemaVersion == 4)
        for leg in decoded.trip.legs {
            #expect(leg.reservation.status.status == .unknown)
            #expect(leg.reservation.status.value == nil)
            #expect(leg.reservation.status.revisions.isEmpty)
            #expect(leg.seatPreference.status == .unknown)
            #expect(leg.seatPreference.value == nil)
        }
        #expect(decoded.trip.name.revisions == trip.name.revisions)
    }

    @Test func v1BookedReservationBecomesUserStatedConfirmedSlot() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.legs[0].reservation.status = try Slot.confirmed(
            value: .notBooked,
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        let encoded = try v1Record(from: trip, statuses: ["booked", "unknown", "cancelled"])
        let decoded = try TripRecordMapper.decode(encoded)
        #expect(decoded.legs[0].reservation.status.value == .booked)
        #expect(decoded.legs[0].reservation.status.status == .confirmed)
        #expect(decoded.legs[0].reservation.status.source == .userStated)
        #expect(decoded.legs[1].reservation.status.status == .unknown)
        #expect(decoded.legs[2].reservation.status.value == .cancelled)
        #expect(decoded.id == trip.id)
    }

    @Test func fetchingV1RecordWritesV2PayloadBack() async throws {
        let repository = try PersistenceStack.inMemory().repository
        let trip = try DomainTestSupport.sampleTrip()
        try await repository.save(trip)
        let v1 = try v1Record(from: trip, statuses: ["notBooked", "unknown", "unknown"])
        try await repository.updateRecord(
            id: trip.id,
            payloadVersion: 1,
            domainSchemaVersion: 1,
            payload: v1.payload
        )

        let loaded = try await repository.fetch(id: trip.id)
        #expect(loaded?.schemaVersion == 4)
        #expect(loaded?.legs[0].reservation.status.value == .notBooked)

        let reloaded = try await repository.fetch(id: trip.id)
        #expect(reloaded == loaded)
        #expect(reloaded?.schemaVersion == 4)
        #expect(reloaded?.legs[0].seatPreference.status == .unknown)
    }

    @Test func v2PayloadGainsUnknownSeatPreference() throws {
        let trip = try DomainTestSupport.sampleTrip()
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 2
        encoded.domainSchemaVersion = 2
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 2
            var legs = json["legs"] as! [[String: Any]]
            for index in legs.indices {
                legs[index].removeValue(forKey: "seatPreference")
            }
            json["legs"] = legs
        }
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.schemaVersion == 4)
        #expect(decoded.rewritten?.payloadVersion == 4)
        #expect(decoded.trip.legs.allSatisfy { $0.seatPreference.status == .unknown })
        #expect(decoded.trip.id == trip.id)
        #expect(decoded.trip.name.revisions == trip.name.revisions)
        #expect(decoded.trip.stays.isEmpty)
    }

    @Test func v3PayloadGainsEmptyStays() throws {
        let trip = try DomainTestSupport.sampleTrip()
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 3
        encoded.domainSchemaVersion = 3
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 3
            json.removeValue(forKey: "stays")
        }
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.schemaVersion == 4)
        #expect(decoded.rewritten?.payloadVersion == 4)
        #expect(decoded.trip.stays.isEmpty)
        #expect(decoded.trip.id == trip.id)
    }

    private func v1Record(from trip: Trip, statuses: [String]) throws -> EncodedTripRecord {
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 1
        encoded.domainSchemaVersion = 1
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 1
            var legs = json["legs"] as! [[String: Any]]
            for index in legs.indices {
                var reservation = legs[index]["reservation"] as! [String: Any]
                reservation["status"] = statuses[index]
                legs[index]["reservation"] = reservation
                legs[index].removeValue(forKey: "seatPreference")
            }
            json["legs"] = legs
            if var activities = json["activities"] as? [[String: Any]] {
                for index in activities.indices {
                    var reservation = activities[index]["reservation"] as! [String: Any]
                    reservation["status"] = "unknown"
                    activities[index]["reservation"] = reservation
                }
                json["activities"] = activities
            }
        }
        return encoded
    }

    private func mutatedPayload(
        _ payload: Data,
        mutate: (inout [String: Any]) -> Void
    ) throws -> Data {
        var json = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
        mutate(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }
}
