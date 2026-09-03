import Foundation

actor TripStore {
    private let repository: any TripRepository
    private let brain: TripBrain

    init(repository: any TripRepository, brain: TripBrain) {
        self.repository = repository
        self.brain = brain
    }

    func process(tripID: TripID, command: TypedCommand) async throws -> BrainResult {
        guard let trip = try await repository.fetch(id: tripID) else {
            throw EngineError.tripNotFound
        }
        let result = try brain.process(trip: trip, command: command)
        try await repository.save(result.updatedTrip)
        return result
    }
}
