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

    /// Moves an already installed sample onto the trip's first morning.
    /// Leaves a date the traveler already chose, and does not recreate a deleted trip.
    func placeOpeningLegIfStillUnscheduled(using repository: SwiftDataTripRepository) async throws {
        guard var trip = try await repository.fetch(id: ReferenceTripIdentity.trip),
              let index = trip.legs.firstIndex(where: { $0.id == ReferenceTripIdentity.tokyoKyoto }),
              trip.legs[index].scheduledAt.status == .unknown
        else {
            return
        }
        let updatedAt = Date()
        trip.legs[index].scheduledAt = try ReferenceTripFactory.openingMorning(updatedAt: updatedAt)
        trip.updatedAt = updatedAt
        try trip.validate()
        try await repository.save(trip)
    }
}
