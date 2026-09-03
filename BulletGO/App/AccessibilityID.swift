import Foundation

enum AccessibilityID {
    static let tripTimeline = "trip-timeline"
    static let tripTimelineEmpty = "trip-timeline-empty"
    static let tripTimelineLoading = "trip-timeline-loading"
    static let tripTimelineFailed = "trip-timeline-failed"
    static let tripTimelineRetry = "trip-timeline-retry"
    static let nowSection = "now-section"
    static let comingUpSection = "coming-up-section"
    static let rememberedSection = "remembered-section"
    static let knownSection = "known-section"
    static let stillNeededSection = "still-needed-section"
    static let routeRail = "route-rail"
    static let resumeGuidance = "resume-guidance"
    static let legDetail = "leg-detail"
    static let startGuidance = "start-guidance"
    static let comingSoonView = "coming-soon-view"
    static let guidanceSheet = "guidance-sheet"
    static let guidanceCompose = "guidance-compose"
    static let guidanceInput = "guidance-input"
    static let guidanceSubmit = "guidance-submit"
    static let guidanceSummary = "guidance-summary"
    static let guidanceContinue = "guidance-continue"
    static let guidanceQuestion = "guidance-question"
    static let guidanceReady = "guidance-ready"
    static let guidanceClose = "guidance-close"
    static let guidanceFallback = "guidance-fallback"
    static let guidanceRetry = "guidance-retry"
    static let taskDetail = "task-detail"
    static let taskPrimaryAction = "task-primary-action"
    static let baggageCheck = "baggage-check"
    static let baggageLength = "baggage-length"
    static let baggageWidth = "baggage-width"
    static let baggageHeight = "baggage-height"
    static let baggageSubmit = "baggage-submit"
    static let baggageResult = "baggage-result"
    static let dateConfirm = "date-confirm"
    static let keyboardDone = "keyboard-done"

    static func timelineLeg(_ id: LegID) -> String {
        "timeline-leg-\(id.rawValue.uuidString)"
    }

    static func timelineActivity(_ id: ActivityID) -> String {
        "timeline-activity-\(id.rawValue.uuidString)"
    }

    static func nowTask(contentKey: String) -> String {
        "now-task-\(contentKey)"
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

    static func questionChoice(_ value: String) -> String {
        "question-choice-\(value)"
    }

    static func questionSkip(_ id: QuestionID) -> String {
        "question-skip-\(id.rawValue)"
    }
}
