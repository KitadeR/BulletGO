import Foundation

nonisolated enum AppRoute: Hashable, Sendable {
    case comingSoon(AppFeature)
    case legDetail(TripID, LegID)
    case stayDetail(TripID, StayID)
    case activityDetail(TripID, ActivityID)
    case taskDetail(TripID, TaskID)
    case baggageCheck(TripID, LegID, TaskID)
    case tripMap(TripID)
    case savedPlaces(TripID)
}

nonisolated enum GuidanceEntry: Hashable, Sendable {
    case compose
    case resume
}

nonisolated enum GuidanceCompletion: Hashable, Sendable {
    case showHome
    case stayInPlace
}

nonisolated enum ItineraryInputScope: Hashable, Sendable {
    case trip
    case leg(LegID)
    case stay(StayID)
    case activity(ActivityID)
}

nonisolated enum ItineraryAddKind: String, Hashable, Codable, Sendable {
    case activity
    case travel
    case stay
}

nonisolated enum AppPresentation: Hashable, Identifiable, Sendable {
    case guidance(TripID, LegID, GuidanceEntry, GuidanceCompletion)
    case createTrip
    case editTrip(TripID)
    case switchTrip
    case addItineraryItem(TripID, initialDate: LocalDate?)
    case guidedAdd(TripID, ItineraryAddKind, initialDate: LocalDate?, seedPlace: PlaceReference?)
    case itineraryTalk(TripID, ItineraryInputScope)

    var id: String {
        switch self {
        case .guidance(let tripID, let legID, let entry, let completion):
            return "guidance-\(tripID.rawValue.uuidString)-\(legID.rawValue.uuidString)-\(entry)-\(completion)"
        case .createTrip:
            return "create-trip"
        case .editTrip(let tripID):
            return "edit-trip-\(tripID.rawValue.uuidString)"
        case .switchTrip:
            return "switch-trip"
        case .addItineraryItem(let tripID, let initialDate):
            if let initialDate {
                return "add-itinerary-\(tripID.rawValue.uuidString)-\(initialDate.displayString)"
            }
            return "add-itinerary-\(tripID.rawValue.uuidString)"
        case .guidedAdd(let tripID, let kind, let initialDate, let seedPlace):
            var id = "guided-add-\(kind.rawValue)-\(tripID.rawValue.uuidString)"
            if let initialDate {
                id += "-\(initialDate.displayString)"
            }
            if let seedPlace {
                id += "-\(seedPlace.name)"
            }
            return id
        case .itineraryTalk(let tripID, let scope):
            return "itinerary-talk-\(tripID.rawValue.uuidString)-\(scope)"
        }
    }
}
