import Foundation
import MapKit

struct MapKitRouteEstimator: RouteEstimating {
    func estimate(
        from: GeoCoordinate,
        to: GeoCoordinate,
        mode: ConnectorTransportMode
    ) async throws -> RouteEstimate {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: from.latitude, longitude: from.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: to.latitude, longitude: to.longitude),
            address: nil
        )
        request.transportType = mode.directionsType
        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw PlaceServiceError.noRoute
        }
        return RouteEstimate(
            mode: mode,
            durationSeconds: route.expectedTravelTime,
            distanceMeters: route.distance
        )
    }
}

struct FakeRouteEstimator: RouteEstimating {
    var result: RouteEstimate

    func estimate(
        from: GeoCoordinate,
        to: GeoCoordinate,
        mode: ConnectorTransportMode
    ) async throws -> RouteEstimate {
        _ = from
        _ = to
        return RouteEstimate(
            mode: mode,
            durationSeconds: result.durationSeconds,
            distanceMeters: result.distanceMeters
        )
    }
}

enum PlaceServiceError: Error {
    case noRoute
}

extension ConnectorTransportMode {
    var directionsType: MKDirectionsTransportType {
        switch self {
        case .walking: .walking
        case .automobile: .automobile
        case .transit: .transit
        }
    }
}

enum ConnectorEstimateComposer {
    static func coordinate(for item: TripTimelineItem, in trip: Trip) -> GeoCoordinate? {
        switch item {
        case .leg(let id):
            guard let leg = trip.legs.first(where: { $0.id == id }) else { return nil }
            return leg.destinationPlace?.coordinate ?? leg.originPlace?.coordinate
        case .stay(let id):
            return trip.stays.first(where: { $0.id == id })?.placeReference?.coordinate
        case .activity(let id):
            return trip.activities.first(where: { $0.id == id })?.placeReference?.coordinate
        }
    }

    static func cached(from: TripTimelineItem, to: TripTimelineItem, in trip: Trip) -> ConnectorEstimate? {
        trip.connectorEstimates.first { $0.fromItem == from && $0.toItem == to }
    }
}
