import Foundation

nonisolated enum ConnectorEstimateComposer {
    static func exitCoordinate(for item: TripTimelineItem, in trip: Trip) -> GeoCoordinate? {
        coordinate(for: item, in: trip, role: .exit)
    }

    static func entryCoordinate(for item: TripTimelineItem, in trip: Trip) -> GeoCoordinate? {
        coordinate(for: item, in: trip, role: .entry)
    }

    static func coordinate(
        for item: TripTimelineItem,
        in trip: Trip,
        role: ConnectorAnchorRole = .exit
    ) -> GeoCoordinate? {
        switch item {
        case .leg(let id):
            guard let leg = trip.legs.first(where: { $0.id == id }) else { return nil }
            switch role {
            case .exit:
                return leg.destinationPlace?.coordinate
            case .entry:
                return leg.originPlace?.coordinate
            }
        case .stay(let id):
            return trip.stays.first(where: { $0.id == id })?.placeReference?.coordinate
        case .activity(let id):
            return trip.activities.first(where: { $0.id == id })?.placeReference?.coordinate
        }
    }

    static func cacheKey(
        from: TripTimelineItem,
        to: TripTimelineItem,
        mode: ConnectorTransportMode,
        in trip: Trip
    ) -> ConnectorCacheKey {
        ConnectorCacheKey(
            fromItem: from,
            toItem: to,
            mode: mode,
            originFingerprint: coordinate(for: from, in: trip, role: .exit)?.fingerprint,
            destinationFingerprint: coordinate(for: to, in: trip, role: .entry)?.fingerprint
        )
    }

    static func edgeIdentity(_ estimate: ConnectorEstimate) -> String {
        "\(estimate.fromItem)|\(estimate.toItem)"
    }

    static func cached(from: TripTimelineItem, to: TripTimelineItem, in trip: Trip) -> ConnectorEstimate? {
        trip.connectorEstimates.first { estimate in
            cacheKey(from: from, to: to, mode: estimate.estimate.mode, in: trip) == ConnectorCacheKey(estimate)
        }
    }

    static func makeEstimate(
        from: TripTimelineItem,
        to: TripTimelineItem,
        estimate: RouteEstimate,
        in trip: Trip,
        at now: Date
    ) -> ConnectorEstimate {
        ConnectorEstimate(
            fromItem: from,
            toItem: to,
            estimate: estimate,
            updatedAt: now,
            originFingerprint: coordinate(for: from, in: trip, role: .exit)?.fingerprint,
            destinationFingerprint: coordinate(for: to, in: trip, role: .entry)?.fingerprint
        )
    }
}
