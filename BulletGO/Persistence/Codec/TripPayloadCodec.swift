import Foundation

nonisolated enum TripPayloadCodec {
    static let currentPayloadVersion = 2

    static func encode(_ trip: Trip) throws -> Data {
        do {
            return try makeEncoder().encode(trip)
        } catch {
            throw PersistenceError.encodingFailed
        }
    }

    static func decode(_ data: Data) throws -> Trip {
        do {
            return try makeDecoder().decode(Trip.self, from: data)
        } catch {
            throw mapDecodeError(error)
        }
    }

    static func decodeMigrating(payload: Data, payloadVersion: Int) throws -> (trip: Trip, payload: Data, payloadVersion: Int) {
        switch payloadVersion {
        case currentPayloadVersion:
            return (try decode(payload), payload, payloadVersion)
        case 1:
            let migrated = try TripPayloadMigrator.migrateV1Payload(payload)
            return (try decode(migrated), migrated, currentPayloadVersion)
        default:
            throw PersistenceError.unsupportedPayloadVersion(payloadVersion)
        }
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    static func mapDecodeError(_ error: Error) -> PersistenceError {
        if let persistenceError = error as? PersistenceError {
            return persistenceError
        }
        if let domainError = error as? DomainError {
            return .invalidDomainValue(domainError)
        }
        if let context = decodingContext(from: error), let underlying = context.underlyingError {
            return mapDecodeError(underlying)
        }
        return .decodingFailed
    }

    private static func decodingContext(from error: Error) -> DecodingError.Context? {
        switch error as? DecodingError {
        case .dataCorrupted(let context),
             .keyNotFound(_, let context),
             .typeMismatch(_, let context),
             .valueNotFound(_, let context):
            return context
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }
}
