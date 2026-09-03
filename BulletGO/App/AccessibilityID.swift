import Foundation

enum AccessibilityID {
    static let tripTimeline = "trip-timeline"
    static let tripTimelineEmpty = "trip-timeline-empty"
    static let tripTimelineLoading = "trip-timeline-loading"
    static let tripTimelineFailed = "trip-timeline-failed"
    static let tripTimelineRetry = "trip-timeline-retry"
    static let comingUpSection = "coming-up-section"
    static let rememberedSection = "remembered-section"
    static let legDetail = "leg-detail"
    static let openFeatureHub = "open-feature-hub"
    static let featureHubList = "feature-hub-list"
    static let comingSoonView = "coming-soon-view"

    static func featureRow(_ feature: AppFeature) -> String {
        "feature-row-\(feature.rawValue)"
    }

    static func timelineLeg(_ id: LegID) -> String {
        "timeline-leg-\(id.rawValue.uuidString)"
    }

    static func timelineActivity(_ id: ActivityID) -> String {
        "timeline-activity-\(id.rawValue.uuidString)"
    }

    static func comingUpTask(_ id: TaskID) -> String {
        "coming-up-task-\(id.rawValue.uuidString)"
    }

    static func comingUpRemembered(contentKey: String, scope: DomainScope) -> String {
        switch scope {
        case .trip:
            "coming-up-remembered-trip-\(contentKey)"
        case .leg(let id):
            "coming-up-remembered-\(id.rawValue.uuidString)-\(contentKey)"
        case .activity(let id):
            "coming-up-remembered-activity-\(id.rawValue.uuidString)-\(contentKey)"
        }
    }

    static func rememberedRow(_ contentKey: String) -> String {
        "remembered-row-\(contentKey)"
    }
}
