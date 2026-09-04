import Foundation

actor TripStore {
    private let repository: any TripRepository
    private let brain: TripBrain

    init(repository: any TripRepository, brain: TripBrain) {
        self.repository = repository
        self.brain = brain
    }

    func fetchAll() async throws -> [Trip] {
        try await repository.fetchAll()
    }

    func fetch(id: TripID) async throws -> Trip? {
        try await repository.fetch(id: id)
    }

    func process(tripID: TripID, command: TypedCommand) async throws -> BrainResult {
        guard let trip = try await repository.fetch(id: tripID) else {
            throw EngineError.tripNotFound
        }
        let result = try brain.process(trip: trip, command: command)
        try await repository.save(result.updatedTrip)
        return result
    }

    func create(_ trip: Trip) async throws {
        try trip.validate()
        try await repository.save(trip)
    }
}
