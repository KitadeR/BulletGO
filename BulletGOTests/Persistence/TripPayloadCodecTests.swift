import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TripPayloadCodecTests {
    @Test func sampleTripRoundTripsThroughPayloadCodec() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let decoded = try TripPayloadCodec.decode(TripPayloadCodec.encode(trip))
        #expect(decoded == trip)
        try decoded.validate()
    }

    @Test func mapperRoundTripsSlotRevisions() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let later = DomainTestSupport.timestamp.addingTimeInterval(90)
        trip.name = try trip.name.updating(
            value: "Confirmed Japan trip",
            status: .confirmed,
            source: .userConfirmed,
            confidence: .high,
            at: later
        )
        trip.updatedAt = later

        let decoded = try TripRecordMapper.decode(TripRecordMapper.encode(trip))
        #expect(decoded == trip)
        #expect(decoded.name.revisions.count == 1)
        #expect(decoded.name.revisions[0].status == .inferred)
        #expect(decoded.name.revisions[0].value == "Japan trip")
    }

    @Test func mapperRejectsInvalidAggregate() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.legs.append(trip.legs[0])
        #expect(throws: PersistenceError.invalidAggregate(.duplicateLegIDs)) {
            try TripRecordMapper.encode(trip)
        }
    }

    @Test func mapperRejectsUnsupportedPayloadVersion() throws {
        var encoded = try TripRecordMapper.encode(DomainTestSupport.sampleTrip())
        encoded.payloadVersion = 99
        #expect(throws: PersistenceError.unsupportedPayloadVersion(99)) {
            try TripRecordMapper.decode(encoded)
        }
    }

    @Test func mapperRejectsTripIDMismatch() throws {
        var encoded = try TripRecordMapper.encode(DomainTestSupport.sampleTrip())
        encoded.tripID = UUID()
        #expect(throws: PersistenceError.tripIDMismatch) {
            try TripRecordMapper.decode(encoded)
        }
    }

    @Test func mapperRejectsDomainSchemaVersionMismatch() throws {
        var encoded = try TripRecordMapper.encode(DomainTestSupport.sampleTrip())
        encoded.domainSchemaVersion = 99
        #expect(throws: PersistenceError.domainSchemaVersionMismatch) {
            try TripRecordMapper.decode(encoded)
        }
    }

    @Test func mapperRejectsInvalidSlotPayload() throws {
        var encoded = try TripRecordMapper.encode(DomainTestSupport.sampleTrip())
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            var name = json["name"] as! [String: Any]
            name["status"] = "unknown"
            name["value"] = "Japan trip"
            json["name"] = name
        }
        #expect(
            throws: PersistenceError.invalidDomainValue(
                .invalidSlotCombination(status: .unknown, source: .aiInferred, hasValue: true)
            )
        ) {
            try TripRecordMapper.decode(encoded)
        }
    }

    @Test func mapperRejectsInvalidDatePayload() throws {
        var encoded = try TripRecordMapper.encode(DomainTestSupport.sampleTrip())
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            var startDate = json["startDate"] as! [String: Any]
            var value = startDate["value"] as! [String: Any]
            value["day"] = 32
            startDate["value"] = value
            json["startDate"] = startDate
        }
        #expect(throws: PersistenceError.invalidDomainValue(.invalidDate(year: 2026, month: 10, day: 32))) {
            try TripRecordMapper.decode(encoded)
        }
    }

    @Test func mapperRejectsInvalidDimensionsPayload() throws {
        let now = DomainTestSupport.timestamp
        var trip = try DomainTestSupport.sampleTrip()
        let bag = Bag(
            id: BagID(),
            kind: try Slot.confirmed(value: .suitcase, source: .userStated, updatedAt: now),
            userDescription: try Slot.unknown(updatedAt: now),
            perceivedSize: try Slot.unknown(updatedAt: now),
            dimensions: try Slot.confirmed(
                value: BaggageDimensions(lengthCM: 80, widthCM: 50, heightCM: 30),
                source: .userStated,
                updatedAt: now
            ),
            weightKilograms: try Slot.unknown(updatedAt: now),
            createdAt: now
        )
        trip.baggageInventory = [bag]
        var encoded = try TripRecordMapper.encode(trip)
        encoded.payload = try mutatedPayload(encoded.payload) { json in
            var inventory = json["baggageInventory"] as! [[String: Any]]
            var dimensions = inventory[0]["dimensions"] as! [String: Any]
            var value = dimensions["value"] as! [String: Any]
            value["lengthCM"] = 0
            dimensions["value"] = value
            inventory[0]["dimensions"] = dimensions
            json["baggageInventory"] = inventory
        }
        #expect(throws: PersistenceError.invalidDomainValue(.invalidBaggageDimension)) {
            try TripRecordMapper.decode(encoded)
        }
    }

    @Test func mapperRejectsMalformedJSON() throws {
        var encoded = try TripRecordMapper.encode(DomainTestSupport.sampleTrip())
        encoded.payload = Data("{".utf8)
        #expect(throws: PersistenceError.decodingFailed) {
            try TripRecordMapper.decode(encoded)
        }
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
