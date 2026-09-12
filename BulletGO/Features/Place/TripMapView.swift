import MapKit
import SwiftUI

struct TripMapView: View {
    @Environment(TripSessionModel.self) private var session
    let tripID: TripID

    var body: some View {
        Group {
            if annotations.isEmpty {
                ContentUnavailableView {
                    Label("No mapped places yet", systemImage: "map")
                } description: {
                    Text("Search for a place while adding an activity, stay, or journey. You can still finish with typed names.")
                }
            } else {
                Map {
                    ForEach(annotations) { annotation in
                        Marker(annotation.name, coordinate: annotation.coordinate)
                    }
                }
                .mapStyle(.standard)
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.tripMap)
    }

    private var annotations: [TripMapAnnotation] {
        guard let trip = session.trip, trip.id == tripID else { return [] }
        return TripMapComposer.annotations(for: trip)
    }
}

nonisolated struct TripMapAnnotation: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: TripMapAnnotation, rhs: TripMapAnnotation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated enum TripMapComposer {
    static func annotations(for trip: Trip) -> [TripMapAnnotation] {
        var result: [TripMapAnnotation] = []
        for activity in trip.activities {
            if let annotation = annotation(
                id: "activity-\(activity.id.rawValue.uuidString)",
                name: activity.title.value ?? activity.place.value ?? "",
                place: activity.placeReference
            ) {
                result.append(annotation)
            }
        }
        for stay in trip.stays {
            if let annotation = annotation(
                id: "stay-\(stay.id.rawValue.uuidString)",
                name: stay.place.value ?? "",
                place: stay.placeReference
            ) {
                result.append(annotation)
            }
        }
        for leg in trip.legs {
            if let annotation = annotation(
                id: "leg-origin-\(leg.id.rawValue.uuidString)",
                name: leg.origin.value ?? "",
                place: leg.originPlace
            ) {
                result.append(annotation)
            }
            if let annotation = annotation(
                id: "leg-destination-\(leg.id.rawValue.uuidString)",
                name: leg.destination.value ?? "",
                place: leg.destinationPlace
            ) {
                result.append(annotation)
            }
        }
        return result
    }

    private static func annotation(id: String, name: String, place: PlaceReference?) -> TripMapAnnotation? {
        guard let coordinate = place?.coordinate else { return nil }
        let title = name.isEmpty ? (place?.name ?? "") : name
        guard !title.isEmpty else { return nil }
        return TripMapAnnotation(
            id: id,
            name: title,
            coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
    }
}
