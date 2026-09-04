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
    static let legSetup = "leg-setup"
    static let legSetupCurrent = "leg-setup-current"
    static let legSetupPaused = "leg-setup-paused"
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
    static let createTripSheet = "create-trip-sheet"
    static let createTripName = "create-trip-name"
    static let createTripSave = "create-trip-save"
    static let createTripButton = "create-trip-button"
    static let addItinerarySheet = "add-itinerary-sheet"
    static let addItineraryButton = "add-itinerary-button"
    static let addItineraryKind = "add-itinerary-kind"
    static let addItineraryOrigin = "add-itinerary-origin"
    static let addItineraryDestination = "add-itinerary-destination"
    static let addItinerarySave = "add-itinerary-save"
    static let itineraryTalkSheet = "itinerary-talk-sheet"
    static let itineraryTalkInput = "itinerary-talk-input"
    static let itineraryTalkSubmit = "itinerary-talk-submit"
    static let itineraryDraftReview = "itinerary-draft-review"
    static let itineraryDraftConfirm = "itinerary-draft-confirm"
    static let itineraryUnscheduled = "itinerary-unscheduled"
    static let stayDetail = "stay-detail"
    static let activityDetail = "activity-detail"
    static let talkAboutTrip = "talk-about-trip"
    static let homeTab = "tab-home"
    static let tripsTab = "tab-trips"
    static let youTab = "tab-you"
    static let contextualHome = "contextual-home"
    static let contextualHomeEmpty = "contextual-home-empty"
    static let contextualHomeLoading = "contextual-home-loading"
    static let contextualHomeFailed = "contextual-home-failed"
    static let primaryNow = "primary-now"
    static let todaySchedule = "today-schedule"
    static let preparationOverview = "preparation-overview"
    static let youView = "you-view"
    static let youLanguage = "you-language"
    static let youLuggage = "you-luggage"
    static let youDocuments = "you-documents"
    static let youSettings = "you-settings"
    static let finishedOpenTrips = "finished-open-trips"
    static let baggageGuide = "baggage-guide"
    static let baggageGuideNext = "baggage-guide-next"
    static let baggageGuideDone = "baggage-guide-done"
    static let legCockpitSummary = "leg-cockpit-summary"
    static let legCockpitReadiness = "leg-cockpit-readiness"
    static let legCockpitWhatsNext = "leg-cockpit-whats-next"

    static func timelineLeg(_ id: LegID) -> String {
        "timeline-leg-\(id.rawValue.uuidString)"
    }

    static func timelineStay(_ id: StayID) -> String {
        "timeline-stay-\(id.rawValue.uuidString)"
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
        case .stay(let id):
            "coming-up-remembered-stay-\(id.rawValue.uuidString)-\(contentKey)"
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

    static func setupStep(_ id: QuestionID) -> String {
        "setup-step-\(id.rawValue)"
    }
}
