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

    enum ProcessState: Equatable, Sendable {
        case idle
        case processing
        case failed
    }

    private(set) var loadState: LoadState
    private(set) var processState: ProcessState
    private(set) var trip: Trip?
    private(set) var lastBrainResult: BrainResult?
    private(set) var catalog: QuestionCatalog?
    private(set) var pack: BaggagePolicyPack?
    private let store: TripStore?
    private let interpreter: any TripInputInterpreting

    init(store: TripStore, interpreter: any TripInputInterpreting = LocalDeterministicTripInputInterpreter()) {
        self.store = store
        self.interpreter = interpreter
        self.loadState = .loading
        self.processState = .idle
        self.trip = nil
        self.lastBrainResult = nil
        self.catalog = try? QuestionCatalogLoader.loadProduction(from: .main)
        self.pack = try? PackLoader.loadProduction(from: .main)
    }

    init(
        previewState: LoadState,
        trip: Trip? = nil,
        lastBrainResult: BrainResult? = nil
    ) {
        self.store = nil
        self.interpreter = LocalDeterministicTripInputInterpreter()
        self.loadState = previewState
        self.processState = .idle
        self.trip = trip
        self.lastBrainResult = lastBrainResult
        self.catalog = try? QuestionCatalogLoader.loadProduction(from: .main)
        self.pack = try? PackLoader.loadProduction(from: .main)
    }

    func interpret(_ text: String, legID: LegID) -> TripInputInterpretation {
        guard let trip else {
            return .empty
        }
        return interpreter.interpret(text, trip: trip, legID: legID)
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
        processState = .idle
    }

    @discardableResult
    func process(_ command: TypedCommand) async -> BrainResult? {
        guard let store, let trip else {
            return nil
        }
        processState = .processing
        do {
            let result = try await store.process(tripID: trip.id, command: command)
            apply(result)
            return result
        } catch {
            processState = .failed
            return nil
        }
    }
}
