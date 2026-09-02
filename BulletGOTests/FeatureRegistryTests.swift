import Foundation
import Testing
@testable import BulletGO

@MainActor
struct FeatureRegistryTests {
    @Test func implementedRegistrationRequiresDestination() {
        #expect(throws: FeatureRegistrationError.implementedRequiresRoute) {
            try FeatureRegistration(
                feature: .baggageCheck,
                title: "Baggage check",
                summary: "Check oversized luggage rules before you travel.",
                systemImage: "suitcase",
                availability: .implemented
            )
        }
    }

    @Test func stubRegistrationMustNotHaveDestination() {
        #expect(throws: FeatureRegistrationError.nonImplementedMustNotHaveRoute) {
            try FeatureRegistration(
                feature: .baggageCheck,
                title: "Baggage check",
                summary: "Check oversized luggage rules before you travel.",
                systemImage: "suitcase",
                availability: .stub,
                destination: .featureHub
            )
        }
    }

    @Test func hiddenRegistrationMustNotHaveDestination() {
        #expect(throws: FeatureRegistrationError.nonImplementedMustNotHaveRoute) {
            try FeatureRegistration(
                feature: .tripSharing,
                title: "Trip sharing",
                summary: "Share the itinerary with companions.",
                systemImage: "square.and.arrow.up",
                availability: .hidden,
                destination: .featureHub
            )
        }
    }

    @Test func implementedRegistrationExposesDestination() throws {
        let registration = try FeatureRegistration(
            feature: .baggageCheck,
            title: "Baggage check",
            summary: "Check oversized luggage rules before you travel.",
            systemImage: "suitcase",
            availability: .implemented,
            destination: .featureHub
        )
        #expect(registration.navigationRoute == .featureHub)
    }

    @Test func stubRegistrationRoutesToComingSoon() throws {
        let registration = try FeatureRegistration(
            feature: .baggageCheck,
            title: "Baggage check",
            summary: "Check oversized luggage rules before you travel.",
            systemImage: "suitcase",
            availability: .stub
        )
        #expect(registration.navigationRoute == .comingSoon(.baggageCheck))
    }

    @Test func hiddenRegistrationHasNoNavigationRoute() throws {
        let registration = try FeatureRegistration(
            feature: .tripSharing,
            title: "Trip sharing",
            summary: "Share the itinerary with companions.",
            systemImage: "square.and.arrow.up",
            availability: .hidden
        )
        #expect(registration.navigationRoute == nil)
    }

    @Test func productionRegistryRegistersEveryFeature() {
        let features = Set(FeatureRegistry.production.registrations.map(\.feature))
        #expect(features == Set(AppFeature.allCases))
    }

    @Test func productionImplementedFeaturesHaveDestinations() {
        for registration in FeatureRegistry.production.registrations {
            switch registration.availability {
            case .implemented:
                #expect(registration.destination != nil)
            case .stub, .hidden:
                #expect(registration.destination == nil)
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
}
