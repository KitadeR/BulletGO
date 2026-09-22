import Foundation

nonisolated enum PlaceProvider: String, Hashable, Codable, Sendable {
    case appleMaps
    case manual
}

nonisolated struct GeoCoordinate: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    var isValid: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    var fingerprint: String {
        String(format: "%.5f,%.5f", latitude, longitude)
    }
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

    static func resolved(_ reference: PlaceReference?, name: String) -> PlaceReference {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var reference else {
            return .manual(name: trimmed)
        }
        if reference.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reference.name = trimmed
        }
        return reference
    }

    var displayAddress: String? {
        let trimmed = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var isSearchResolved: Bool {
        provider == .appleMaps
    }

    var japaneseCategorySubtitle: String? {
        let formatted = PlaceDisplayFormatting.guidedAddSubtitle(address: displayAddress, category: category)
        return formatted.isEmpty ? nil : formatted
    }
}

nonisolated enum PlaceSearchFailure: Error, Equatable, Sendable {
    case unavailable
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

nonisolated enum PlaceDisplayFormatting {
    static func guidedAddSubtitle(address: String?, category: String?) -> String {
        let region = regionLabel(in: address)
        let kind = categoryLabel(category) ?? categoryLabel(in: address)
        switch (region, kind) {
        case (let region?, let kind?):
            return "日本・\(region)・\(kind)"
        case (let region?, nil):
            return "日本・\(region)"
        case (nil, let kind?):
            return "日本・\(kind)"
        default:
            return address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private static func regionLabel(in address: String?) -> String? {
        guard let address, !address.isEmpty else { return nil }
        if address.contains("東京") || address.localizedCaseInsensitiveContains("Tokyo") { return "東京都" }
        if address.contains("大阪") || address.localizedCaseInsensitiveContains("Osaka") { return "大阪府" }
        if address.contains("京都") || address.localizedCaseInsensitiveContains("Kyoto") { return "京都府" }
        if address.contains("兵庫") || address.contains("神戸") || address.localizedCaseInsensitiveContains("Hyogo") || address.localizedCaseInsensitiveContains("Kobe") {
            return "兵庫県"
        }
        if address.contains("奈良") || address.localizedCaseInsensitiveContains("Nara") { return "奈良県" }
        return nil
    }

    private static func categoryLabel(_ category: String?) -> String? {
        guard let category else { return nil }
        let lowered = category.lowercased()
        if lowered.contains("publictransport") || lowered.contains("station") { return "駅" }
        if lowered.contains("airport") { return "空港" }
        if lowered.contains("landmark") { return "観光名所" }
        if lowered.contains("park") { return "公園" }
        if lowered.contains("hotel") || lowered.contains("lodging") { return "宿泊" }
        return nil
    }

    private static func categoryLabel(in address: String?) -> String? {
        guard let address else { return nil }
        if address.contains("駅") || address.localizedCaseInsensitiveContains("Station") { return "駅" }
        if address.contains("空港") || address.localizedCaseInsensitiveContains("Airport") { return "空港" }
        return nil
    }
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

nonisolated struct ConnectorCacheKey: Hashable, Sendable {
    var fromItem: TripTimelineItem
    var toItem: TripTimelineItem
    var mode: ConnectorTransportMode
    var originFingerprint: String?
    var destinationFingerprint: String?

    init(
        fromItem: TripTimelineItem,
        toItem: TripTimelineItem,
        mode: ConnectorTransportMode,
        originFingerprint: String?,
        destinationFingerprint: String?
    ) {
        self.fromItem = fromItem
        self.toItem = toItem
        self.mode = mode
        self.originFingerprint = originFingerprint
        self.destinationFingerprint = destinationFingerprint
    }

    init(_ estimate: ConnectorEstimate) {
        self.init(
            fromItem: estimate.fromItem,
            toItem: estimate.toItem,
            mode: estimate.estimate.mode,
            originFingerprint: estimate.originFingerprint,
            destinationFingerprint: estimate.destinationFingerprint
        )
    }
}

nonisolated struct ConnectorEstimate: Hashable, Codable, Sendable {
    var fromItem: TripTimelineItem
    var toItem: TripTimelineItem
    var estimate: RouteEstimate
    var updatedAt: Date
    var originFingerprint: String?
    var destinationFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case fromItem, toItem, estimate, updatedAt, originFingerprint, destinationFingerprint
    }

    init(
        fromItem: TripTimelineItem,
        toItem: TripTimelineItem,
        estimate: RouteEstimate,
        updatedAt: Date,
        originFingerprint: String? = nil,
        destinationFingerprint: String? = nil
    ) {
        self.fromItem = fromItem
        self.toItem = toItem
        self.estimate = estimate
        self.updatedAt = updatedAt
        self.originFingerprint = originFingerprint
        self.destinationFingerprint = destinationFingerprint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fromItem = try container.decode(TripTimelineItem.self, forKey: .fromItem)
        toItem = try container.decode(TripTimelineItem.self, forKey: .toItem)
        estimate = try container.decode(RouteEstimate.self, forKey: .estimate)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        originFingerprint = try container.decodeIfPresent(String.self, forKey: .originFingerprint)
        destinationFingerprint = try container.decodeIfPresent(String.self, forKey: .destinationFingerprint)
    }
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
