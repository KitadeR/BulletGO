import Foundation
import MapKit

@MainActor
final class MapKitPlaceSearch: NSObject, PlaceSearching, MKLocalSearchCompleterDelegate, @unchecked Sendable {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[PlaceSearchCompletion], Error>?
    private var generation = 0

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    private var lastQuery = ""

    func completions(for query: String) async throws -> [PlaceSearchCompletion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        generation += 1
        let current = generation
        lastQuery = trimmed
        if let pending = continuation {
            continuation = nil
            pending.resume(returning: [])
        }
        return try await withCheckedThrowingContinuation { continuation in
            guard current == generation else {
                continuation.resume(returning: [])
                return
            }
            self.continuation = continuation
            completer.queryFragment = trimmed
        }
    }

    func lookup(_ completion: PlaceSearchCompletion) async throws -> PlaceReference {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [completion.title, completion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            return .manual(name: completion.title)
        }
        return PlaceReference(
            provider: .appleMaps,
            providerID: nil,
            name: item.name ?? completion.title,
            coordinate: GeoCoordinate(
                latitude: item.location.coordinate.latitude,
                longitude: item.location.coordinate.longitude
            ),
            address: item.address?.shortAddress ?? completion.subtitle,
            category: item.pointOfInterestCategory?.rawValue
        )
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            finish(completer.results.map { result in
                PlaceSearchCompletion(
                    id: "\(result.title)|\(result.subtitle)",
                    title: result.title,
                    subtitle: result.subtitle
                )
            })
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            finish([], error: error)
        }
    }

    private func finish(_ results: [PlaceSearchCompletion], error: Error? = nil) {
        guard completer.queryFragment == lastQuery, let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(returning: results)
        }
    }
}

struct FakePlaceSearch: PlaceSearching {
    var completions: [PlaceSearchCompletion] = []
    var places: [String: PlaceReference] = [:]

    func completions(for query: String) async throws -> [PlaceSearchCompletion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return completions.filter {
            $0.title.lowercased().contains(trimmed) || $0.subtitle.lowercased().contains(trimmed)
        }
    }

    func lookup(_ completion: PlaceSearchCompletion) async throws -> PlaceReference {
        places[completion.id] ?? .manual(name: completion.title)
    }
}
