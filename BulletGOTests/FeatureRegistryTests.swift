import Foundation
import Testing
@testable import BulletGO

@MainActor
struct FeatureRegistryTests {
    @Test func implementedRegistrationRequiresDestinationKind() {
        #expect(throws: FeatureRegistrationError.implementedRequiresDestinationKind) {
            try FeatureRegistration(
                feature: .baggageCheck,
                title: "Baggage check",
                summary: "Check oversized luggage rules before you travel.",
                systemImage: "suitcase",
                availability: .implemented
            )
        }
    }

    @Test func stubRegistrationMustNotHaveDestinationKind() {
        #expect(throws: FeatureRegistrationError.nonImplementedMustNotHaveDestinationKind) {
            try FeatureRegistration(
                feature: .baggageCheck,
                title: "Baggage check",
                summary: "Check oversized luggage rules before you travel.",
                systemImage: "suitcase",
                availability: .stub,
                destinationKind: .baggageCheck
            )
        }
    }

    @Test func hiddenRegistrationMustNotHaveDestinationKind() {
        #expect(throws: FeatureRegistrationError.nonImplementedMustNotHaveDestinationKind) {
            try FeatureRegistration(
                feature: .tripSharing,
                title: "Trip sharing",
                summary: "Share the itinerary with companions.",
                systemImage: "square.and.arrow.up",
                availability: .hidden,
                destinationKind: .baggageCheck
            )
        }
    }

    @Test func productionRegistryRegistersEveryFeature() {
        let features = Set(FeatureRegistry.production.registrations.map(\.feature))
        #expect(features == Set(AppFeature.allCases))
    }

    @Test func productionImplementedFeaturesHaveDestinationKinds() {
        for registration in FeatureRegistry.production.registrations {
            switch registration.availability {
            case .implemented:
                #expect(registration.destinationKind != nil)
            case .stub, .hidden:
                #expect(registration.destinationKind == nil)
            }
        }
    }

    @Test func visibleFeaturesExcludeHidden() {
        let visible = FeatureRegistry.production.visibleFeatures.map(\.feature)
        #expect(!visible.contains(.tripSharing))
        #expect(visible.contains(.baggageCheck))
        #expect(Set(visible).count == AppFeature.allCases.count - 1)
    }

    @Test func incompleteRegistryThrows() {
        #expect(throws: FeatureRegistryError.incompleteCoverage) {
            try FeatureRegistry(registrations: [])
        }
    }

    @Test func baggageCheckResolvesOnlyWithContext() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let taskID = TaskID()
        let resolved = FeatureRegistry.production.resolve(
            .baggageCheck,
            in: FeatureContext(tripID: trip.id, legID: trip.legs[0].id, taskID: taskID)
        )
        #expect(resolved == .baggageCheck(trip.id, trip.legs[0].id, taskID))
        #expect(
            FeatureRegistry.production.resolve(
                .baggageCheck,
                in: FeatureContext(tripID: trip.id)
            ) == nil
        )
    }

    @Test func bookingMethodStaysContextualComingSoon() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let route = FeatureRegistry.production.resolve(
            .bookingMethod,
            in: FeatureContext(tripID: trip.id, legID: trip.legs[0].id, taskID: TaskID())
        )
        #expect(route == .comingSoon(.bookingMethod))
    }

    @Test func hiddenFeatureHasNoRoute() throws {
        let trip = try DomainTestSupport.sampleTrip()
        #expect(
            FeatureRegistry.production.resolve(
                .tripSharing,
                in: FeatureContext(tripID: trip.id)
            ) == nil
        )
    }
}
