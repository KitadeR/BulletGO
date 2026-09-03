import Foundation
import SwiftData

@ModelActor
actor SwiftDataTripRepository: TripRepository {
    func fetchAll() throws -> [Trip] {
        let descriptor = FetchDescriptor<TripRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { record in
            try TripRecordMapper.decode(snapshot(from: record))
        }
    }

    func fetch(id: TripID) throws -> Trip? {
        guard let record = try record(for: id.rawValue) else {
            return nil
        }
        return try TripRecordMapper.decode(snapshot(from: record))
    }

    func save(_ trip: Trip) throws {
        let encoded = try TripRecordMapper.encode(trip)
        if let existing = try record(for: encoded.tripID) {
            apply(encoded, to: existing)
        } else {
            modelContext.insert(makeRecord(from: encoded))
        }
        try modelContext.save()
    }

    func delete(id: TripID) throws {
        guard let existing = try record(for: id.rawValue) else {
            return
        }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func seedIfNeeded(trip: Trip, key: String, version: Int) throws {
        var markerDescriptor = FetchDescriptor<SeedStateRecord>(
            predicate: #Predicate { $0.seedKey == key }
        )
        markerDescriptor.fetchLimit = 1
        if try modelContext.fetch(markerDescriptor).first != nil {
            return
        }

        let encoded = try TripRecordMapper.encode(trip)
        modelContext.insert(makeRecord(from: encoded))
        modelContext.insert(
            SeedStateRecord(seedKey: key, seedVersion: version, appliedAt: trip.createdAt)
        )
        try modelContext.save()
    }

    func updateRecord(
        id: TripID,
        tripID: UUID? = nil,
        payloadVersion: Int? = nil,
        domainSchemaVersion: Int? = nil,
        payload: Data? = nil
    ) throws {
        guard let existing = try record(for: id.rawValue) else {
            return
        }
        if let tripID {
            existing.tripID = tripID
        }
        if let payloadVersion {
            existing.payloadVersion = payloadVersion
        }
        if let domainSchemaVersion {
            existing.domainSchemaVersion = domainSchemaVersion
        }
        if let payload {
            existing.payload = payload
        }
        try modelContext.save()
    }

    private func record(for tripID: UUID) throws -> TripRecord? {
        var descriptor = FetchDescriptor<TripRecord>(
            predicate: #Predicate { $0.tripID == tripID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func snapshot(from record: TripRecord) -> EncodedTripRecord {
        EncodedTripRecord(
            tripID: record.tripID,
            displayName: record.displayName,
            startDateSortKey: record.startDateSortKey,
            payloadVersion: record.payloadVersion,
            domainSchemaVersion: record.domainSchemaVersion,
            payload: record.payload,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private func apply(_ encoded: EncodedTripRecord, to record: TripRecord) {
        record.tripID = encoded.tripID
        record.displayName = encoded.displayName
        record.startDateSortKey = encoded.startDateSortKey
        record.payloadVersion = encoded.payloadVersion
        record.domainSchemaVersion = encoded.domainSchemaVersion
        record.payload = encoded.payload
        record.createdAt = encoded.createdAt
        record.updatedAt = encoded.updatedAt
    }

    private func makeRecord(from encoded: EncodedTripRecord) -> TripRecord {
        TripRecord(
            tripID: encoded.tripID,
            displayName: encoded.displayName,
            startDateSortKey: encoded.startDateSortKey,
            payloadVersion: encoded.payloadVersion,
            domainSchemaVersion: encoded.domainSchemaVersion,
            payload: encoded.payload,
            createdAt: encoded.createdAt,
            updatedAt: encoded.updatedAt
        )
    }
}
