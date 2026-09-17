import Foundation
import MapKit

@MainActor
final class MapKitPlaceSearch: NSObject, PlaceSearching, MKLocalSearchCompleterDelegate, @unchecked Sendable {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[PlaceSearchCompletion], Error>?
    private var lastQuery = ""
    private var completionCache: [String: MKLocalSearchCompletion] = [:]

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func completions(for query: String) async throws -> [PlaceSearchCompletion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        lastQuery = trimmed
        completer.cancel()
        if let pending = continuation {
            continuation = nil
            pending.resume(returning: [])
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            completer.queryFragment = trimmed
        }
    }

    func lookup(_ completion: PlaceSearchCompletion) async throws -> PlaceReference {
        guard let cached = completionCache[completion.id] else {
            throw PlaceSearchFailure.unavailable
        }
        let request = MKLocalSearch.Request(completion: cached)
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch {
            throw PlaceSearchFailure.unavailable
        }
        guard let item = response.mapItems.first else {
            throw PlaceSearchFailure.unavailable
        }
        return place(from: item, fallbackName: completion.title, fallbackAddress: completion.subtitle)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            finish(mappedCompletions(from: completer.results))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            finish([], error: PlaceSearchFailure.unavailable)
        }
    }

    private func mappedCompletions(from results: [MKLocalSearchCompletion]) -> [PlaceSearchCompletion] {
        var cache: [String: MKLocalSearchCompletion] = [:]
        let mapped = results.map { result -> PlaceSearchCompletion in
            let id = "\(result.title)|\(result.subtitle)"
            cache[id] = result
            return PlaceSearchCompletion(id: id, title: result.title, subtitle: result.subtitle)
        }
        completionCache = cache
        return mapped
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

    private func place(from item: MKMapItem, fallbackName: String, fallbackAddress: String) -> PlaceReference {
        let coordinate = GeoCoordinate(
            latitude: item.location.coordinate.latitude,
            longitude: item.location.coordinate.longitude
        )
        let address = item.address?.fullAddress
            ?? item.address?.shortAddress
            ?? (fallbackAddress.isEmpty ? nil : fallbackAddress)
        return PlaceReference(
            provider: .appleMaps,
            providerID: item.identifier?.rawValue,
            name: item.name ?? fallbackName,
            coordinate: coordinate.isValid ? coordinate : nil,
            address: address,
            category: item.pointOfInterestCategory?.rawValue
        )
    }
}

struct FakePlaceSearch: PlaceSearching {
    var completions: [PlaceSearchCompletion] = []
    var places: [String: PlaceReference] = [:]
    var completionsError: PlaceSearchFailure?
    var lookupError: PlaceSearchFailure?
    var delay: Duration = .zero

    static let uiTesting = FakePlaceSearch(
        completions: [
            PlaceSearchCompletion(id: "kinkaku", title: "Kinkaku-ji", subtitle: "1 Kinkakujicho, Kita-ku, Kyoto"),
            PlaceSearchCompletion(id: "fushimi", title: "Fushimi Inari Taisha", subtitle: "Kyoto"),
            PlaceSearchCompletion(id: "tokyo", title: "Tokyo Station", subtitle: "Chiyoda City, Tokyo"),
            PlaceSearchCompletion(id: "osaka", title: "Osaka Station", subtitle: "Osaka"),
            PlaceSearchCompletion(id: "nara", title: "Nara Park", subtitle: "Nara"),
        ],
        places: [
            "kinkaku": PlaceReference(
                provider: .appleMaps,
                providerID: "poi-kinkaku",
                name: "Kinkaku-ji",
                coordinate: GeoCoordinate(latitude: 35.0394, longitude: 135.7292),
                address: "1 Kinkakujicho, Kita-ku, Kyoto",
                category: "MKPOICategoryLandmark"
            ),
            "fushimi": PlaceReference(
                provider: .appleMaps,
                providerID: "poi-fushimi",
                name: "Fushimi Inari Taisha",
                coordinate: GeoCoordinate(latitude: 34.9671, longitude: 135.7727),
                address: "Kyoto",
                category: "MKPOICategoryLandmark"
            ),
            "tokyo": PlaceReference(
                provider: .appleMaps,
                providerID: "poi-tokyo",
                name: "Tokyo Station",
                coordinate: GeoCoordinate(latitude: 35.6812, longitude: 139.7671),
                address: "Chiyoda City, Tokyo",
                category: "MKPOICategoryPublicTransport"
            ),
            "osaka": PlaceReference(
                provider: .appleMaps,
                providerID: "poi-osaka",
                name: "Osaka Station",
                coordinate: GeoCoordinate(latitude: 34.7024, longitude: 135.4959),
                address: "Osaka",
                category: "MKPOICategoryPublicTransport"
            ),
            "nara": PlaceReference(
                provider: .appleMaps,
                providerID: "poi-nara",
                name: "Nara Park",
                coordinate: GeoCoordinate(latitude: 34.6851, longitude: 135.8430),
                address: "Nara",
                category: "MKPOICategoryPark"
            ),
        ]
    )

    func completions(for query: String) async throws -> [PlaceSearchCompletion] {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        if let completionsError {
            throw completionsError
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return completions.filter {
            $0.title.lowercased().contains(trimmed) || $0.subtitle.lowercased().contains(trimmed)
        }
    }

    func lookup(_ completion: PlaceSearchCompletion) async throws -> PlaceReference {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        if let lookupError {
            throw lookupError
        }
        return places[completion.id] ?? .manual(name: completion.title)
    }
}
