import Foundation

enum AccessibilityID {
    static let tripTimelineEmpty = "trip-timeline-empty"
    static let openFeatureHub = "open-feature-hub"
    static let featureHubList = "feature-hub-list"
    static let comingSoonView = "coming-soon-view"

    static func featureRow(_ feature: AppFeature) -> String {
        "feature-row-\(feature.rawValue)"
    }
}
