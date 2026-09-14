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
        #expect(decoded.trip.schemaVersion == 7)
        #expect(decoded.rewritten?.payloadVersion == 7)
        #expect(decoded.rewritten?.domainSchemaVersion == 7)
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
        #expect(loaded?.schemaVersion == 7)
        #expect(loaded?.legs[0].reservation.status.value == .notBooked)

        let reloaded = try await repository.fetch(id: trip.id)
        #expect(reloaded == loaded)
        #expect(reloaded?.schemaVersion == 7)
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
        #expect(decoded.trip.schemaVersion == 7)
        #expect(decoded.rewritten?.payloadVersion == 7)
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
        #expect(decoded.trip.schemaVersion == 7)
        #expect(decoded.rewritten?.payloadVersion == 7)
        #expect(decoded.trip.stays.isEmpty)
        #expect(decoded.trip.id == trip.id)
        #expect(decoded.trip.savedPlaces.isEmpty)
        #expect(decoded.trip.notes.isEmpty)
        #expect(decoded.trip.attachments.isEmpty)
    }

    @Test func v4PayloadGainsFoundationCollections() throws {
        let trip = try DomainTestSupport.sampleTrip()
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 4
        encoded.domainSchemaVersion = 4
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 4
            json.removeValue(forKey: "savedPlaces")
            json.removeValue(forKey: "notes")
            json.removeValue(forKey: "attachments")
            json.removeValue(forKey: "connectorEstimates")
        }
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.schemaVersion == 7)
        #expect(decoded.rewritten?.payloadVersion == 7)
        #expect(decoded.trip.savedPlaces.isEmpty)
        #expect(decoded.trip.notes.isEmpty)
        #expect(decoded.trip.attachments.isEmpty)
        #expect(decoded.trip.connectorEstimates.isEmpty)
        #expect(decoded.trip.legs.allSatisfy { $0.arrivesAt.status == .unknown })
        #expect(decoded.trip.activities.allSatisfy { $0.endsAt.status == .unknown })
        #expect(decoded.trip.daySubtitles.isEmpty)
    }

    @Test func v5PayloadGainsEmptyDaySubtitles() throws {
        let trip = try DomainTestSupport.sampleTrip()
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 5
        encoded.domainSchemaVersion = 5
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 5
            json.removeValue(forKey: "daySubtitles")
        }
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.schemaVersion == 7)
        #expect(decoded.rewritten?.payloadVersion == 7)
        #expect(decoded.rewritten?.domainSchemaVersion == 7)
        #expect(decoded.trip.daySubtitles.isEmpty)
        #expect(decoded.trip.id == trip.id)
    }

    @Test func v6PayloadLiftsEndTimeAndDropsConnectorCache() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let date = try LocalDate(year: 2026, month: 10, day: 3)
        trip.activities[0].scheduledAt = try Slot.confirmed(
            value: ScheduledMoment(
                date: date,
                time: try LocalTime(hour: 10, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.activities[0].endsAt = try Slot.unknown(updatedAt: DomainTestSupport.timestamp)
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 6
        encoded.domainSchemaVersion = 6
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 6
            json["connectorEstimates"] = [[
                "fromItem": ["leg": trip.legs[0].id.rawValue.uuidString],
                "toItem": ["activity": trip.activities[0].id.rawValue.uuidString],
                "estimate": [
                    "mode": "walking",
                    "durationSeconds": 600,
                    "distanceMeters": 800,
                ],
                "updatedAt": DomainTestSupport.timestamp.timeIntervalSince1970,
            ]]
            var activities = json["activities"] as! [[String: Any]]
            var scheduled = activities[0]["scheduledAt"] as! [String: Any]
            var value = scheduled["value"] as! [String: Any]
            value["endTime"] = ["hour": 12, "minute": 0, "second": 0]
            scheduled["value"] = value
            activities[0]["scheduledAt"] = scheduled
            json["activities"] = activities
        }
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.schemaVersion == 7)
        #expect(decoded.rewritten?.payloadVersion == 7)
        #expect(decoded.trip.connectorEstimates.isEmpty)
        #expect(decoded.trip.activities[0].scheduledAt.value?.time?.hour == 10)
        #expect(decoded.trip.activities[0].endsAt.value?.time?.hour == 12)
        #expect(decoded.trip.activities[0].scheduledAt.value?.date == date)
        let roundTrip = try TripPayloadCodec.decode(try TripPayloadCodec.encode(decoded.trip))
        #expect(roundTrip.activities[0].endsAt.value?.time?.hour == 12)
    }

    @Test func v6KnownEndDoesNotLiftEndTime() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let date = try LocalDate(year: 2026, month: 10, day: 3)
        trip.activities[0].scheduledAt = try Slot.confirmed(
            value: ScheduledMoment(
                date: date,
                time: try LocalTime(hour: 10, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.activities[0].endsAt = try Slot.confirmed(
            value: ScheduledMoment(
                date: date,
                time: try LocalTime(hour: 11, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payloadVersion = 6
        encoded.domainSchemaVersion = 6
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            json["schemaVersion"] = 6
            var activities = json["activities"] as! [[String: Any]]
            var scheduled = activities[0]["scheduledAt"] as! [String: Any]
            var value = scheduled["value"] as! [String: Any]
            value["endTime"] = ["hour": 12, "minute": 0, "second": 0]
            scheduled["value"] = value
            activities[0]["scheduledAt"] = scheduled
            json["activities"] = activities
        }
        let decoded = try TripRecordMapper.decodeWithMigration(encoded)
        #expect(decoded.trip.activities[0].endsAt.value?.time?.hour == 11)
        #expect(decoded.trip.activities[0].scheduledAt.value?.time?.hour == 10)
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
