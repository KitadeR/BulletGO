import Foundation
import Testing
@testable import BulletGO

@MainActor
struct PlaceSearchModelTests {
    @Test func successReturnsMatchingCompletions() async throws {
        let search = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")
            ],
            places: ["kinkaku": Self.kinkaku]
        )
        let model = PlaceSearchModel(search: search, debounce: .zero)
        model.updateQuery("Kin")
        try await waitUntil { !model.isSearching && !model.completions.isEmpty }
        #expect(model.completions.map(\.id) == ["kinkaku"])
        #expect(model.failure == nil)
        #expect(model.showsEmptyResults == false)
    }

    @Test func noResultsShowsEmptyState() async throws {
        let model = PlaceSearchModel(search: FakePlaceSearch(), debounce: .zero)
        model.updateQuery("Nowhere")
        try await waitUntil { !model.isSearching }
        #expect(model.completions.isEmpty)
        #expect(model.showsEmptyResults)
    }

    @Test func errorThenRetryReloadsResults() async throws {
        let failing = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")
            ],
            completionsError: .unavailable
        )
        let model = PlaceSearchModel(search: failing, debounce: .zero)
        model.updateQuery("Kin")
        try await waitUntil { model.failure != nil }
        #expect(model.failure == .unavailable)
        #expect(model.completions.isEmpty)

        model.search = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")
            ]
        )
        model.retry()
        try await waitUntil { !model.isSearching && !model.completions.isEmpty }
        #expect(model.failure == nil)
        #expect(model.completions.count == 1)
    }

    @Test func staleResponseIsIgnored() async throws {
        let search = ScriptedPlaceSearch()
        search.responses["ki"] = .init(
            delay: .milliseconds(80),
            completions: [PlaceSearchCompletion(id: "old", title: "Old", subtitle: "")]
        )
        search.responses["kinkaku"] = .init(
            delay: .milliseconds(10),
            completions: [PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")]
        )
        let model = PlaceSearchModel(search: search, debounce: .zero)
        model.updateQuery("ki")
        model.updateQuery("kinkaku")
        try await waitUntil { !model.isSearching && model.completions.first?.id == "kinkaku" }
        #expect(model.completions.map(\.id) == ["kinkaku"])
    }

    @Test func selectionKeepsMapKitPlace() async throws {
        let search = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")
            ],
            places: ["kinkaku": Self.kinkaku]
        )
        let model = PlaceSearchModel(search: search, debounce: .zero)
        model.updateQuery("Kin")
        try await waitUntil { !model.completions.isEmpty }
        await model.select(model.completions[0])
        #expect(model.selected?.provider == .appleMaps)
        #expect(model.selected?.providerID == "poi-kinkaku")
        #expect(model.query == "Kinkaku-ji")
        #expect(model.completions.isEmpty)
    }

    @Test func restoreSelectedKeepsResolvedPlaceWithoutSearching() {
        let model = PlaceSearchModel(search: FakePlaceSearch(), debounce: .zero)
        model.restoreSelected(Self.kinkaku)
        #expect(model.selected?.providerID == "poi-kinkaku")
        #expect(model.query == "Kinkaku-ji")
        #expect(model.completions.isEmpty)
        #expect(model.isSearching == false)
    }

    @Test func reopenForReselectionClearsSelectionAndSearches() async throws {
        let search = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")
            ],
            places: ["kinkaku": Self.kinkaku]
        )
        let model = PlaceSearchModel(search: search, debounce: .zero)
        model.restoreSelected(Self.kinkaku)
        model.reopenForReselection()
        #expect(model.selected == nil)
        try await waitUntil { !model.isSearching && !model.completions.isEmpty }
        #expect(model.completions.map(\.id) == ["kinkaku"])
    }

    @Test func lookupFailureLeavesManualTypingPath() async throws {
        let search = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "Kyoto")
            ],
            places: ["kinkaku": Self.kinkaku],
            lookupError: .unavailable
        )
        let model = PlaceSearchModel(search: search, debounce: .zero)
        model.updateQuery("Kin")
        try await waitUntil { !model.completions.isEmpty }
        await model.select(model.completions[0])
        #expect(model.selected == nil)
        #expect(model.query == "Kinkaku-ji")
        #expect(model.failure == .unavailable)
    }

    private static let kinkaku = PlaceReference(
        provider: .appleMaps,
        providerID: "poi-kinkaku",
        name: "Kinkaku-ji",
        coordinate: GeoCoordinate(latitude: 35.0394, longitude: 135.7292),
        address: "1 Kinkakujicho, Kita-ku, Kyoto",
        category: "MKPOICategoryLandmark"
    )
}

@MainActor
private final class ScriptedPlaceSearch: PlaceSearching, @unchecked Sendable {
    struct Response {
        var delay: Duration = .zero
        var completions: [PlaceSearchCompletion] = []
        var error: PlaceSearchFailure?
    }

    var responses: [String: Response] = [:]

    func completions(for query: String) async throws -> [PlaceSearchCompletion] {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response = responses[key] ?? Response()
        if response.delay > .zero {
            try await Task.sleep(for: response.delay)
        }
        if let error = response.error {
            throw error
        }
        return response.completions
    }

    func lookup(_ completion: PlaceSearchCompletion) async throws -> PlaceReference {
        .manual(name: completion.title)
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for place search state")
}
