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
    static let createTripDateRangeConfirm = "create-trip-date-range-confirm"
    static let createTripButton = "create-trip-button"
    static let itineraryUnscheduled = "itinerary-unscheduled"
    static let stayDetail = "stay-detail"
    static let activityDetail = "activity-detail"
    static let tripsDateSelector = "trips-date-selector"
    static let tripsDateRange = "trips-date-range"
    static let tripsDaySubtitleSheet = "trips-day-subtitle-sheet"
    static let tripsDaySubtitleField = "trips-day-subtitle-field"
    static let tripsDaySubtitleSave = "trips-day-subtitle-save"
    static let tripsDaySubtitleClear = "trips-day-subtitle-clear"
    static let tripsV2Screen = "trips-v2-screen"
    static let tripsV2DateStrip = "trips-v2-date-strip"
    static let tripsV2FloatingAdd = "trips-v2-floating-add"
    static let tripsV2AddActivity = "trips-v2-add-activity"
    static let tripsV2AddLeg = "trips-v2-add-leg"
    static let tripsV2AddStay = "trips-v2-add-stay"
    static let guidedAddSheet = "guided-add-sheet"
    static let guidedAddCancel = "guided-add-cancel"
    static let guidedAddBack = "guided-add-back"
    static let guidedAddContinue = "guided-add-continue"
    static let guidedAddSkip = "guided-add-skip"
    static let guidedAddSave = "guided-add-save"
    static let guidedAddTitle = "guided-add-title"
    static let guidedAddOrigin = "guided-add-origin"
    static let guidedAddDestination = "guided-add-destination"
    static let tripSwitcher = "trip-switcher"
    static let tripSwitcherRow = "trip-switcher-row"
    static let tripMap = "trip-map"
    static let savedPlaces = "saved-places"
    static let reservationEditor = "reservation-editor"
    static let notesEditor = "notes-editor"
    static let attachmentsEditor = "attachments-editor"
    static let tripsEmptyDay = "trips-empty-day"
    static let tripsPreparation = "trips-leg-preparation"
    static let tripsQuickContext = "trips-quick-context"
    static let tripsQuickContextDetails = "trips-quick-context-details"
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
    static let homeOpenTrips = "home-open-trips"
    static let finishedOpenTrips = "finished-open-trips"
    static let baggageGuide = "baggage-guide"
    static let baggageGuideNext = "baggage-guide-next"
    static let baggageGuideDone = "baggage-guide-done"
    static let legCockpitSummary = "leg-cockpit-summary"
    static let legCockpitReadiness = "leg-cockpit-readiness"
    static let legCockpitWhatsNext = "leg-cockpit-whats-next"
    static let legCockpitLuggage = "leg-cockpit-luggage"

    static func timelineLeg(_ id: LegID) -> String {
        "timeline-leg-\(id.rawValue.uuidString)"
    }

    static func timelineStay(_ id: StayID, role: StayPresentationRole = .checkIn) -> String {
        switch role {
        case .checkIn:
            "timeline-stay-\(id.rawValue.uuidString)"
        case .staying(let night, _):
            "timeline-stay-\(id.rawValue.uuidString)-night-\(night)"
        case .checkOut:
            "timeline-stay-\(id.rawValue.uuidString)-checkout"
        }
    }

    static func timelineActivity(_ id: ActivityID) -> String {
        "timeline-activity-\(id.rawValue.uuidString)"
    }

    static func tripsQuickContextItem(_ id: String) -> String {
        "trips-quick-context-item-\(id)"
    }

    static func homeScheduleRow(_ id: TimelineRowKind) -> String {
        switch id {
        case .leg(let id):
            "home-schedule-leg-\(id.rawValue.uuidString)"
        case .stay(let id, let role):
            switch role {
            case .checkIn:
                "home-schedule-stay-\(id.rawValue.uuidString)"
            case .staying(let night, _):
                "home-schedule-stay-\(id.rawValue.uuidString)-night-\(night)"
            case .checkOut:
                "home-schedule-stay-\(id.rawValue.uuidString)-checkout"
            }
        case .activity(let id):
            "home-schedule-activity-\(id.rawValue.uuidString)"
        }
    }

    static func tripsDateOption(_ date: LocalDate) -> String {
        "trips-date-\(date.year)-\(date.month)-\(date.day)"
    }

    static func tripsDaySection(_ date: LocalDate) -> String {
        "itinerary-day-\(date.year)-\(date.month)-\(date.day)"
    }

    static func tripsDayAdd(_ date: LocalDate) -> String {
        "trips-day-add-\(date.year)-\(date.month)-\(date.day)"
    }

    static func tripsDaySubtitle(_ date: LocalDate) -> String {
        "trips-day-subtitle-\(date.year)-\(date.month)-\(date.day)"
    }

    static func tripsDaySubtitleAdd(_ date: LocalDate) -> String {
        "trips-day-subtitle-add-\(date.year)-\(date.month)-\(date.day)"
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
