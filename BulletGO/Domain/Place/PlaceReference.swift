import Foundation

nonisolated enum PlaceProvider: String, Hashable, Codable, Sendable {
    case appleMaps
    case manual
}

nonisolated struct GeoCoordinate: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double
}

nonisolated struct PlaceReference: Hashable, Codable, Sendable {
    var provider: PlaceProvider
    var providerID: String?
    var name: String
    var coordinate: GeoCoordinate?
    var address: String?
    var category: String?

    static func manual(name: String) -> PlaceReference {
        PlaceReference(
            provider: .manual,
            providerID: nil,
            name: name,
            coordinate: nil,
            address: nil,
            category: nil
        )
    }
}

nonisolated struct SavedPlace: Hashable, Codable, Sendable, Identifiable {
    let id: SavedPlaceID
    var place: PlaceReference
    var note: String?
    var createdAt: Date
}

nonisolated struct PlaceSearchCompletion: Hashable, Sendable, Identifiable {
    var id: String
    var title: String
    var subtitle: String
}

nonisolated enum ConnectorTransportMode: String, Hashable, Codable, Sendable {
    case walking
    case automobile
    case transit
}

nonisolated struct RouteEstimate: Hashable, Codable, Sendable {
    var mode: ConnectorTransportMode
    var durationSeconds: TimeInterval
    var distanceMeters: Double
}

nonisolated struct ConnectorEstimate: Hashable, Codable, Sendable {
    var fromItem: TripTimelineItem
    var toItem: TripTimelineItem
    var estimate: RouteEstimate
    var updatedAt: Date
}

protocol PlaceSearching: Sendable {
    func completions(for query: String) async throws -> [PlaceSearchCompletion]
    func lookup(_ completion: PlaceSearchCompletion) async throws -> PlaceReference
}

protocol RouteEstimating: Sendable {
    func estimate(
        from: GeoCoordinate,
        to: GeoCoordinate,
        mode: ConnectorTransportMode
    ) async throws -> RouteEstimate
}
