import Foundation

nonisolated struct ReferenceTripSeeder: Sendable {
    static let seedKey = "reference-trip"
    static let seedVersion = 1

    var factory: ReferenceTripFactory

    init(factory: ReferenceTripFactory = ReferenceTripFactory()) {
        self.factory = factory
    }

    func seedIfNeeded(using repository: SwiftDataTripRepository) async throws {
        try await repository.seedIfNeeded(
            trip: factory.makeReferenceTrip(),
            key: Self.seedKey,
            version: Self.seedVersion
        )
    }
}
