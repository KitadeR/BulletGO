import Foundation

nonisolated protocol TripRepository: Sendable {
    func fetchAll() async throws -> [Trip]
    func fetch(id: TripID) async throws -> Trip?
    func save(_ trip: Trip) async throws
    func delete(id: TripID) async throws
}
