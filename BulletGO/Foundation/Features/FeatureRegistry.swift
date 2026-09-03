import Foundation
import SwiftUI

enum FeatureRegistryError: Error, Equatable {
    case incompleteCoverage
    case duplicateFeatures
}

struct FeatureRegistry: Sendable {
    let registrations: [FeatureRegistration]

    var visibleFeatures: [FeatureRegistration] {
        registrations.filter { $0.availability != .hidden }
    }

    init(registrations: [FeatureRegistration]) throws {
        let features = registrations.map(\.feature)
        let uniqueFeatures = Set(features)
        guard uniqueFeatures.count == features.count else {
            throw FeatureRegistryError.duplicateFeatures
        }
        guard uniqueFeatures == Set(AppFeature.allCases) else {
            throw FeatureRegistryError.incompleteCoverage
        }
        self.registrations = registrations
    }

    func registration(for feature: AppFeature) -> FeatureRegistration {
        guard let match = registrations.first(where: { $0.feature == feature }) else {
            preconditionFailure("FeatureRegistry is missing \(feature.rawValue).")
        }
        return match
    }

    func resolve(_ feature: AppFeature, in context: FeatureContext) -> AppRoute? {
        let registration = registration(for: feature)
        switch registration.availability {
        case .hidden:
            return nil
        case .stub:
            return .comingSoon(feature)
        case .implemented:
            switch registration.destinationKind {
            case .baggageCheck:
                guard let legID = context.legID, let taskID = context.taskID else {
                    return nil
                }
                return .baggageCheck(context.tripID, legID, taskID)
            case .none:
                return nil
            }
        }
    }
}

extension FeatureRegistry {
    static let production: FeatureRegistry = {
        do {
            return try FeatureRegistry(
                registrations: [
                    try FeatureRegistration(
                        feature: .baggageCheck,
                        title: LocalizedStringResource(
                            "Baggage check",
                            comment: "Feature hub title for checking oversized luggage rules."
                        ),
                        summary: LocalizedStringResource(
                            "Check oversized luggage rules before you travel.",
                            comment: "One-line explanation of baggage check."
                        ),
                        systemImage: "suitcase",
                        availability: .implemented,
                        destinationKind: .baggageCheck
                    ),
                    try FeatureRegistration(
                        feature: .departureReminder,
                        title: LocalizedStringResource(
                            "Departure reminder",
                            comment: "Feature hub title for departure reminders."
                        ),
                        summary: LocalizedStringResource(
                            "Get a heads-up before you need to leave.",
                            comment: "One-line explanation of departure reminder."
                        ),
                        systemImage: "bell",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .operationStatus,
                        title: LocalizedStringResource(
                            "Service updates",
                            comment: "Feature hub title for delay and service-status guidance."
                        ),
                        summary: LocalizedStringResource(
                            "How to check delays and what to do next.",
                            comment: "One-line explanation of service updates."
                        ),
                        systemImage: "tram.fill",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .ocrItinerary,
                        title: LocalizedStringResource(
                            "Scan itinerary",
                            comment: "Feature hub title for reading a ticket email or screenshot."
                        ),
                        summary: LocalizedStringResource(
                            "Turn a ticket email or screenshot into a trip.",
                            comment: "One-line explanation of itinerary scanning."
                        ),
                        systemImage: "doc.viewfinder",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .bookingMethod,
                        title: LocalizedStringResource(
                            "How to book",
                            comment: "Feature hub title for choosing a booking method."
                        ),
                        summary: LocalizedStringResource(
                            "Find the booking option that fits you.",
                            comment: "One-line explanation of booking method guidance."
                        ),
                        systemImage: "ticket",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .vehicleEquipment,
                        title: LocalizedStringResource(
                            "Train facilities",
                            comment: "Feature hub title for onboard train facilities."
                        ),
                        summary: LocalizedStringResource(
                            "Seats, outlets, and onboard equipment.",
                            comment: "One-line explanation of train facilities."
                        ),
                        systemImage: "train.side.front.car",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .gateToPlatform,
                        title: LocalizedStringResource(
                            "Gate to platform time",
                            comment: "Feature hub title for typical ticket-gate-to-platform time."
                        ),
                        summary: LocalizedStringResource(
                            "Typical time from ticket gate to platform.",
                            comment: "One-line explanation of gate-to-platform estimates."
                        ),
                        systemImage: "figure.walk",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .liveActivity,
                        title: LocalizedStringResource(
                            "Live Activity",
                            comment: "Feature hub title for Lock Screen Live Activity."
                        ),
                        summary: LocalizedStringResource(
                            "Keep the current step on the Lock Screen.",
                            comment: "One-line explanation of Live Activity."
                        ),
                        systemImage: "platter.filled.top.iphone",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .stationInfo,
                        title: LocalizedStringResource(
                            "Station info",
                            comment: "Feature hub title for station layout and nearby tips."
                        ),
                        summary: LocalizedStringResource(
                            "Station layout and nearby tips.",
                            comment: "One-line explanation of station info."
                        ),
                        systemImage: "building.2",
                        availability: .stub
                    ),
                    try FeatureRegistration(
                        feature: .tripSharing,
                        title: LocalizedStringResource(
                            "Trip sharing",
                            comment: "Hidden feature title for sharing a trip with companions."
                        ),
                        summary: LocalizedStringResource(
                            "Share the itinerary with companions.",
                            comment: "One-line explanation of trip sharing."
                        ),
                        systemImage: "square.and.arrow.up",
                        availability: .hidden
                    ),
                ]
            )
        } catch {
            preconditionFailure("Production FeatureRegistry is invalid: \(error)")
        }
    }()
}

extension EnvironmentValues {
    @Entry var featureRegistry: FeatureRegistry = .production
}
