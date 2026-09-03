import Foundation
import Observation

@MainActor
@Observable
final class TripSessionModel {
    enum LoadState: Equatable, Sendable {
        case loading
        case loaded
        case empty
        case failed
    }

    private(set) var loadState: LoadState
    private(set) var trip: Trip?
    private(set) var lastBrainResult: BrainResult?
    private let store: TripStore?

    init(store: TripStore) {
        self.store = store
        self.loadState = .loading
        self.trip = nil
        self.lastBrainResult = nil
    }

    init(previewState: LoadState, trip: Trip? = nil) {
        self.store = nil
        self.loadState = previewState
        self.trip = trip
        self.lastBrainResult = nil
    }

    func load() async {
        guard let store else {
            return
        }
        loadState = .loading
        do {
            let trips = try await store.fetchAll().sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }
            if let currentID = trip?.id, let match = trips.first(where: { $0.id == currentID }) {
                trip = match
                loadState = .loaded
            } else if let selected = trips.first {
                trip = selected
                lastBrainResult = nil
                loadState = .loaded
            } else {
                trip = nil
                lastBrainResult = nil
                loadState = .empty
            }
        } catch {
            trip = nil
            lastBrainResult = nil
            loadState = .failed
        }
    }

    func retry() async {
        await load()
    }

    func apply(_ result: BrainResult) {
        trip = result.updatedTrip
        lastBrainResult = result
        loadState = .loaded
    }
}
