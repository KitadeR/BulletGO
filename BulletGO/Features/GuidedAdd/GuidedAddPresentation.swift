import Foundation

nonisolated enum GuidedAddStep: Hashable, Sendable {
    case activityWhat
    case activityDate
    case activityTiming
    case activityReview
    case travelPlaces
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
        case .activityWhat: "予定を追加"
        case .activityDate: "いつ"
        case .activityTiming: "時刻"
        case .activityReview: "確認"
        case .travelPlaces: "移動を追加"
        case .travelMode: "どう行く？"
        case .travelSchedule: "いつ"
        case .travelReview: "確認"
        case .stayPlace: "宿泊を追加"
        case .stayCheckIn: "チェックイン"
        case .stayCheckOut: "チェックアウト"
        case .stayReview: "確認"
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

nonisolated enum TravelTimeKind: String, Hashable, Sendable, CaseIterable, Identifiable {
    case undecided
    case departure
    case arrival
    case firstTrain
    case lastTrain

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .undecided: "まだ決めていない"
        case .departure: "出発"
        case .arrival: "到着"
        case .firstTrain: "始発"
        case .lastTrain: "終電"
        }
    }

    var needsClock: Bool {
        switch self {
        case .departure, .arrival: true
        case .undecided, .firstTrain, .lastTrain: false
        }
    }
}

struct LegAddDraft: Equatable {
    var origin: String = ""
    var destination: String = ""
    var mode: TransportMode?
    var hasDate: Bool = true
    var date: Date = Date()
    var timeKind: TravelTimeKind = .undecided
    var skippedTime: Bool = false
    var clockConfirmed: Bool = false
    var departureTime: Date = Date()
    var arrivalTime: Date = Date().addingTimeInterval(7200)
    var originPlace: PlaceReference?
    var destinationPlace: PlaceReference?

    var hasResolvedOrigin: Bool {
        originPlace?.isSearchResolved == true
    }

    var hasResolvedDestination: Bool {
        destinationPlace?.isSearchResolved == true
    }
}

enum TravelGuidedAdd {
    static let modes: [TransportMode] = [.airplane, .shinkansen, .localTrain]

    static func modeTitle(_ mode: TransportMode) -> LocalizedStringResource {
        switch mode {
        case .airplane: "飛行機"
        case .shinkansen: "新幹線"
        case .localTrain: "在来線"
        default: "その他"
        }
    }

    static func modeSymbol(_ mode: TransportMode) -> String {
        switch mode {
        case .airplane: "airplane"
        case .shinkansen: "train.side.front.car"
        case .localTrain: "tram.fill"
        default: "point.bottomleft.forward.to.point.topright.scurvepath"
        }
    }

    static func modeImage(_ mode: TransportMode) -> String? {
        switch mode {
        case .airplane: "GuidedAddAirplane"
        case .shinkansen: "GuidedAddShinkansen"
        case .localTrain: "GuidedAddLocalTrain"
        default: nil
        }
    }
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
            [.travelPlaces, .travelMode, .travelSchedule, .travelReview]
        case .stay:
            [.stayPlace, .stayCheckIn, .stayCheckOut, .stayReview]
        }
    }

    static func seedDraft(kind: ItineraryAddKind, initialDate: LocalDate?, now: Date, seedPlace: PlaceReference? = nil) -> GuidedAddDraft {
        let date = initialDate.flatMap { $0.date(in: TripCalendar.timeZone) } ?? now
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
