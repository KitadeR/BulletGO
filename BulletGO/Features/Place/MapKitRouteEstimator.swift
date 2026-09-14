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
