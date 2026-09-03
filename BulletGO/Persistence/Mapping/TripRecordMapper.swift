import Foundation

nonisolated struct EncodedTripRecord: Equatable, Sendable {
    var tripID: UUID
    var displayName: String
    var startDateSortKey: String?
    var payloadVersion: Int
    var domainSchemaVersion: Int
    var payload: Data
    var createdAt: Date
    var updatedAt: Date
}

nonisolated enum TripRecordMapper {
    static func encode(_ trip: Trip) throws -> EncodedTripRecord {
        do {
            try trip.validate()
        } catch let error as TripValidationError {
            throw PersistenceError.invalidAggregate(error)
        }
        return EncodedTripRecord(
            tripID: trip.id.rawValue,
            displayName: trip.name.value ?? "",
            startDateSortKey: trip.startDate.value.map(Self.sortKey(for:)),
            payloadVersion: TripPayloadCodec.currentPayloadVersion,
            domainSchemaVersion: trip.schemaVersion,
            payload: try TripPayloadCodec.encode(trip),
            createdAt: trip.createdAt,
            updatedAt: trip.updatedAt
        )
    }

    static func decode(_ encoded: EncodedTripRecord) throws -> Trip {
        guard encoded.payloadVersion == TripPayloadCodec.currentPayloadVersion else {
            throw PersistenceError.unsupportedPayloadVersion(encoded.payloadVersion)
        }
        let trip = try TripPayloadCodec.decode(encoded.payload)
        do {
            try trip.validate()
        } catch let error as TripValidationError {
            throw PersistenceError.invalidAggregate(error)
        }
        guard trip.id.rawValue == encoded.tripID else {
            throw PersistenceError.tripIDMismatch
        }
        guard trip.schemaVersion == encoded.domainSchemaVersion else {
            throw PersistenceError.domainSchemaVersionMismatch
        }
        return trip
    }

    private static func sortKey(for date: LocalDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}
