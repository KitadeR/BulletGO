import Foundation
import Observation

@MainActor
@Observable
final class PlaceSearchModel {
    var search: (any PlaceSearching)?
    private(set) var query = ""
    private(set) var completions: [PlaceSearchCompletion] = []
    private(set) var selected: PlaceReference?
    private(set) var isSearching = false
    private(set) var isResolving = false
    private(set) var failure: PlaceSearchFailure?

    var showsEmptyResults: Bool {
        !isSearching
            && failure == nil
            && selected == nil
            && trimmedQuery.count >= minimumQueryLength
            && completions.isEmpty
    }

    private let debounce: Duration
    private let minimumQueryLength: Int
    private var generation = 0
    private var debounceTask: Task<Void, Never>?

    init(
        search: (any PlaceSearching)? = nil,
        debounce: Duration = .milliseconds(280),
        minimumQueryLength: Int = 2
    ) {
        self.search = search
        self.debounce = debounce
        self.minimumQueryLength = minimumQueryLength
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        if let selected, newValue != selected.name {
            self.selected = nil
        }
        scheduleSearch(immediate: false)
    }

    func searchNow() {
        scheduleSearch(immediate: true)
    }

    func retry() {
        scheduleSearch(immediate: true)
    }

    func select(_ completion: PlaceSearchCompletion) async {
        guard let search else { return }
        generation += 1
        debounceTask?.cancel()
        isResolving = true
        failure = nil
        defer { isResolving = false }
        do {
            let place = try await search.lookup(completion)
            selected = place
            query = place.name
            completions = []
        } catch {
            selected = nil
            query = completion.title
            completions = []
            failure = .unavailable
        }
    }

    func clearSelection() {
        selected = nil
    }

    func restoreSelected(_ place: PlaceReference) {
        selected = place
        query = place.name
        completions = []
        failure = nil
        isSearching = false
        isResolving = false
    }

    func reopenForReselection() {
        selected = nil
        failure = nil
        isResolving = false
        scheduleSearch(immediate: true)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduleSearch(immediate: Bool) {
        generation += 1
        let current = generation
        debounceTask?.cancel()

        if selected != nil {
            completions = []
            isSearching = false
            failure = nil
            return
        }

        let trimmed = trimmedQuery
        guard trimmed.count >= minimumQueryLength else {
            completions = []
            isSearching = false
            failure = nil
            return
        }

        debounceTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: self?.debounce ?? .zero)
            }
            guard !Task.isCancelled else { return }
            await self?.performSearch(query: trimmed, generation: current)
        }
    }

    private func performSearch(query: String, generation current: Int) async {
        guard current == generation else { return }
        guard let search else {
            completions = []
            isSearching = false
            return
        }
        isSearching = true
        failure = nil
        do {
            let results = try await search.completions(for: query)
            guard current == generation else { return }
            completions = results
            isSearching = false
        } catch {
            guard current == generation else { return }
            completions = []
            isSearching = false
            failure = .unavailable
        }
    }
}
