import Foundation

nonisolated enum PersistenceError: Error, Equatable, Sendable {
    case encodingFailed
    case decodingFailed
    case invalidDomainValue(DomainError)
    case invalidAggregate(TripValidationError)
    case tripIDMismatch
    case domainSchemaVersionMismatch
    case unsupportedPayloadVersion(Int)
    case storeCreationFailed
}
