import Foundation

enum FeatureRegistrationError: Error, Equatable {
    case implementedRequiresDestinationKind
    case nonImplementedMustNotHaveDestinationKind
}

struct FeatureRegistration: Identifiable, Sendable {
    let feature: AppFeature
    let title: LocalizedStringResource
    let summary: LocalizedStringResource
    let systemImage: String
    let availability: FeatureAvailability
    let destinationKind: FeatureDestinationKind?

    var id: AppFeature { feature }

    init(
        feature: AppFeature,
        title: LocalizedStringResource,
        summary: LocalizedStringResource,
        systemImage: String,
        availability: FeatureAvailability,
        destinationKind: FeatureDestinationKind? = nil
    ) throws {
        try Self.validate(availability: availability, destinationKind: destinationKind)
        self.feature = feature
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.availability = availability
        self.destinationKind = destinationKind
    }

    static func validate(
        availability: FeatureAvailability,
        destinationKind: FeatureDestinationKind?
    ) throws {
        switch availability {
        case .implemented:
            guard destinationKind != nil else {
                throw FeatureRegistrationError.implementedRequiresDestinationKind
            }
        case .stub, .hidden:
            guard destinationKind == nil else {
                throw FeatureRegistrationError.nonImplementedMustNotHaveDestinationKind
            }
        }
    }
}
