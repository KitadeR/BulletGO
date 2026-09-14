import Foundation
import Testing
@testable import BulletGO

struct ConnectorEstimateTests {
    @Test func cacheHitRequiresMatchingFingerprintsAndOrientation() throws {
        let origin = GeoCoordinate(latitude: 35.6812, longitude: 139.7671)
        let destination = GeoCoordinate(latitude: 34.9858, longitude: 135.7581)
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        var outbound = try ItineraryItemFactory.makeLeg(
            origin: "Tokyo",
            destination: "Kyoto",
            at: EngineTestSupport.now
        )
        outbound.originPlace = PlaceReference(
            provider: .appleMaps,
            providerID: "tokyo",
            name: "Tokyo Station",
            coordinate: origin,
            address: nil,
            category: nil
        )
        outbound.destinationPlace = PlaceReference(
            provider: .appleMaps,
            providerID: "kyoto",
            name: "Kyoto Station",
            coordinate: destination,
            address: nil,
            category: nil
        )
        let temple = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            at: EngineTestSupport.now
        )
        var templeWithPlace = temple
        templeWithPlace.placeReference = PlaceReference(
            provider: .appleMaps,
            providerID: "kinkaku",
            name: "Kinkaku-ji",
            coordinate: GeoCoordinate(latitude: 35.0394, longitude: 135.7292),
            address: nil,
            category: nil
        )
        trip = try TripMutationApplier.apply(
            [
                .addLeg(outbound, atTimelineIndex: nil),
                .addActivity(templeWithPlace, atTimelineIndex: nil),
            ],
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(ConnectorEstimateComposer.exitCoordinate(for: .leg(outbound.id), in: trip) == destination)
        #expect(ConnectorEstimateComposer.entryCoordinate(for: .leg(outbound.id), in: trip) == origin)

        let estimate = ConnectorEstimateComposer.makeEstimate(
            from: .leg(outbound.id),
            to: .activity(templeWithPlace.id),
            estimate: RouteEstimate(mode: .walking, durationSeconds: 900, distanceMeters: 1_200),
            in: trip,
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.cacheConnectorEstimate(estimate), to: trip, at: EngineTestSupport.now)
        #expect(ConnectorEstimateComposer.cached(from: .leg(outbound.id), to: .activity(templeWithPlace.id), in: trip) != nil)

        trip = try TripMutationApplier.apply(
            .updateActivityPlace(
                templeWithPlace.id,
                PlaceReference(
                    provider: .appleMaps,
                    providerID: "gion",
                    name: "Gion",
                    coordinate: GeoCoordinate(latitude: 35.0036, longitude: 135.7781),
                    address: nil,
                    category: nil
                )
            ),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(ConnectorEstimateComposer.cached(from: .leg(outbound.id), to: .activity(templeWithPlace.id), in: trip) == nil)
    }

    @Test func invalidCoordinatesFailValidation() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.activities[0].placeReference = PlaceReference(
            provider: .manual,
            providerID: nil,
            name: "Broken",
            coordinate: GeoCoordinate(latitude: 200, longitude: 0),
            address: nil,
            category: nil
        )
        #expect(throws: TripValidationError.invalidCoordinate) {
            try trip.validate()
        }
    }

    @Test func reorderingInvalidatesAdjacentConnectorAndUndoRestoresOrder() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        var first = try ItineraryItemFactory.makeActivity(title: "Kinkaku-ji", place: "Kyoto", at: EngineTestSupport.now)
        first.placeReference = PlaceReference(
            provider: .appleMaps,
            providerID: "kinkaku",
            name: "Kinkaku-ji",
            coordinate: GeoCoordinate(latitude: 35.0394, longitude: 135.7292),
            address: nil,
            category: nil
        )
        var second = try ItineraryItemFactory.makeActivity(title: "Gion", place: "Kyoto", at: EngineTestSupport.now)
        second.placeReference = PlaceReference(
            provider: .appleMaps,
            providerID: "gion",
            name: "Gion",
            coordinate: GeoCoordinate(latitude: 35.0036, longitude: 135.7781),
            address: nil,
            category: nil
        )
        trip = try TripMutationApplier.apply(
            [
                .addActivity(first, atTimelineIndex: nil),
                .addActivity(second, atTimelineIndex: nil),
            ],
            to: trip,
            at: EngineTestSupport.now
        )
        let estimate = ConnectorEstimateComposer.makeEstimate(
            from: .activity(first.id),
            to: .activity(second.id),
            estimate: RouteEstimate(mode: .walking, durationSeconds: 900, distanceMeters: 1_200),
            in: trip,
            at: EngineTestSupport.now
        )
        let eventCount = trip.changeEvents.count
        let updatedAt = trip.updatedAt
        trip = try TripMutationApplier.apply(.cacheConnectorEstimate(estimate), to: trip, at: EngineTestSupport.now)
        #expect(ConnectorEstimateComposer.cached(from: .activity(first.id), to: .activity(second.id), in: trip) != nil)
        #expect(trip.changeEvents.count == eventCount)
        #expect(trip.updatedAt == updatedAt)

        let originalTimeline = trip.timeline
        let receipt = MutationReceiptPlanner.plan(.moveTimelineItem(from: 1, to: 0), on: trip)
        trip = try TripMutationApplier.apply(.moveTimelineItem(from: 1, to: 0), to: trip, at: EngineTestSupport.now)
        #expect(ConnectorEstimateComposer.cached(from: .activity(first.id), to: .activity(second.id), in: trip) == nil)
        trip = try TripMutationApplier.apply(receipt.inverse, to: trip, at: EngineTestSupport.now)
        #expect(trip.timeline == originalTimeline)
    }
}
