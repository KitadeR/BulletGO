import Foundation

nonisolated enum GuidedAddStep: Hashable, Sendable {
    case activityWhat
    case activityDate
    case activityTiming
    case activityReview
    case travelOrigin
    case travelDestination
    case travelMode
    case travelSchedule
    case travelReview
    case stayPlace
    case stayCheckIn
    case stayCheckOut
    case stayReview

    var isReview: Bool {
        switch self {
        case .activityReview, .travelReview, .stayReview: true
        default: false
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .activityWhat: "Place or activity"
        case .activityDate: "When"
        case .activityTiming: "Time"
        case .activityReview: "Review"
        case .travelOrigin: "From"
        case .travelDestination: "To"
        case .travelMode: "How"
        case .travelSchedule: "When"
        case .travelReview: "Review"
        case .stayPlace: "Stay"
        case .stayCheckIn: "Check-in"
        case .stayCheckOut: "Check-out"
        case .stayReview: "Review"
        }
    }
}

nonisolated enum ActivityTimingChoice: String, Hashable, Sendable, CaseIterable, Identifiable {
    case none
    case allDay
    case start
    case range

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .none: "No specific time"
        case .allDay: "All day"
        case .start: "Start time"
        case .range: "Start and end"
        }
    }
}

struct ActivityAddDraft: Equatable {
    var title: String = ""
    var place: String = ""
    var hasDate: Bool = true
    var date: Date = Date()
    var timing: ActivityTimingChoice = .none
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600)
    var placeReference: PlaceReference?
}

struct LegAddDraft: Equatable {
    var origin: String = ""
    var destination: String = ""
    var mode: TransportMode?
    var skipMode: Bool = false
    var hasDate: Bool = true
    var date: Date = Date()
    var hasDepartureTime: Bool = false
    var departureTime: Date = Date()
    var hasArrivalTime: Bool = false
    var arrivalTime: Date = Date().addingTimeInterval(7200)
    var originPlace: PlaceReference?
    var destinationPlace: PlaceReference?
}

struct StayAddDraft: Equatable {
    var place: String = ""
    var hasCheckIn: Bool = true
    var checkIn: Date = Date()
    var hasCheckOut: Bool = false
    var checkOut: Date = Date().addingTimeInterval(86_400)
    var placeReference: PlaceReference?
}

enum GuidedAddDraft: Equatable {
    case activity(ActivityAddDraft)
    case travel(LegAddDraft)
    case stay(StayAddDraft)
}

enum GuidedAddComposer {
    static func steps(for kind: ItineraryAddKind) -> [GuidedAddStep] {
        switch kind {
        case .activity:
            [.activityWhat, .activityDate, .activityTiming, .activityReview]
        case .travel:
            [.travelOrigin, .travelDestination, .travelMode, .travelSchedule, .travelReview]
        case .stay:
            [.stayPlace, .stayCheckIn, .stayCheckOut, .stayReview]
        }
    }

    static func seedDraft(kind: ItineraryAddKind, initialDate: LocalDate?, now: Date, seedPlace: PlaceReference? = nil) -> GuidedAddDraft {
        let date = initialDate.flatMap { $0.date(in: TimeZone.current) } ?? now
        switch kind {
        case .activity:
            var draft = ActivityAddDraft()
            draft.date = date
            draft.startTime = date
            draft.endTime = date.addingTimeInterval(3600)
            draft.hasDate = initialDate != nil
            if let seedPlace {
                draft.place = seedPlace.name
                draft.title = seedPlace.name
                draft.placeReference = seedPlace
            }
            return .activity(draft)
        case .travel:
            var draft = LegAddDraft()
            draft.date = date
            draft.departureTime = date
            draft.arrivalTime = date.addingTimeInterval(7200)
            draft.hasDate = initialDate != nil
            return .travel(draft)
        case .stay:
            var draft = StayAddDraft()
            draft.checkIn = date
            draft.checkOut = date.addingTimeInterval(86_400)
            draft.hasCheckIn = initialDate != nil
            return .stay(draft)
        }
    }
}
