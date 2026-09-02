import Foundation

enum FeatureRegistrationError: Error, Equatable {
    case implementedRequiresRoute
    case nonImplementedMustNotHaveRoute
}

struct FeatureRegistration: Identifiable, Sendable {
    let feature: AppFeature
    let title: LocalizedStringResource
    let summary: LocalizedStringResource
    let systemImage: String
    let availability: FeatureAvailability
    let destination: AppRoute?

    var id: AppFeature { feature }

    var navigationRoute: AppRoute? {
        switch availability {
        case .implemented:
            destination
        case .stub:
            .comingSoon(feature)
        case .hidden:
            nil
        }
    }

    init(
        feature: AppFeature,
        title: LocalizedStringResource,
        summary: LocalizedStringResource,
        systemImage: String,
        availability: FeatureAvailability,
        destination: AppRoute? = nil
    ) throws {
        try Self.validate(availability: availability, destination: destination)
        self.feature = feature
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.availability = availability
        self.destination = destination
    }

    static func validate(
        availability: FeatureAvailability,
        destination: AppRoute?
    ) throws {
        switch availability {
        case .implemented:
            guard destination != nil else {
                throw FeatureRegistrationError.implementedRequiresRoute
            }
        case .stub, .hidden:
            guard destination == nil else {
                throw FeatureRegistrationError.nonImplementedMustNotHaveRoute
            }
        }
    }
}
