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
    private let draftExtractor: any ItineraryDraftExtracting
    private let clock: EngineClock

    var now: Date { clock.now() }

    init(
        store: TripStore,
        interpreter: any TripInputInterpreting = LocalDeterministicTripInputInterpreter(),
        draftExtractor: any ItineraryDraftExtracting = LocalDeterministicItineraryDraftExtractor(),
        clock: EngineClock = .system
    ) {
        self.store = store
        self.interpreter = interpreter
        self.draftExtractor = draftExtractor
        self.clock = clock
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
        lastBrainResult: BrainResult? = nil,
        clock: EngineClock = .system
    ) {
        self.store = nil
        self.interpreter = LocalDeterministicTripInputInterpreter()
        self.draftExtractor = LocalDeterministicItineraryDraftExtractor()
        self.loadState = previewState
        self.processState = .idle
        self.trip = trip
        self.lastBrainResult = lastBrainResult
        self.catalog = try? QuestionCatalogLoader.loadProduction(from: .main)
        self.pack = try? PackLoader.loadProduction(from: .main)
        self.clock = clock
    }

    func interpret(_ text: String, legID: LegID) -> TripInputInterpretation {
        guard let trip else {
            return .empty
        }
        return interpreter.interpret(text, trip: trip, legID: legID)
    }

    func extractItineraryDraft(_ text: String, scope: ItineraryInputScope, trip: Trip) async throws -> ProposedItineraryDraft {
        try await draftExtractor.extract(text, scope: scope, trip: trip)
    }

    func load(showLoading: Bool = true) async {
        guard let store else {
            return
        }
        if showLoading {
            loadState = .loading
        }
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
        if loadState == .loaded, trip != nil {
            _ = await process(.reevaluate)
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

    func createTrip(name: String, startDate: LocalDate, endDate: LocalDate) async throws -> Bool {
        guard let store else {
            return false
        }
        processState = .processing
        do {
            let created = try EmptyTripFactory.make(
                name: name,
                startDate: startDate,
                endDate: endDate
            )
            try await store.create(created)
            trip = created
            lastBrainResult = nil
            loadState = .loaded
            processState = .idle
            _ = await process(.reevaluate)
            return true
        } catch {
            processState = .failed
            return false
        }
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
