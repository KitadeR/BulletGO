import Foundation

nonisolated enum AppRoute: Hashable, Sendable {
    case comingSoon(AppFeature)
    case legDetail(TripID, LegID)
    case stayDetail(TripID, StayID)
    case activityDetail(TripID, ActivityID)
    case taskDetail(TripID, TaskID)
    case baggageCheck(TripID, LegID, TaskID)
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

nonisolated enum AppPresentation: Hashable, Identifiable, Sendable {
    case guidance(TripID, LegID, GuidanceEntry, GuidanceCompletion)
    case createTrip
    case addItineraryItem(TripID)
    case itineraryTalk(TripID, ItineraryInputScope)

    var id: String {
        switch self {
        case .guidance(let tripID, let legID, let entry, let completion):
            "guidance-\(tripID.rawValue.uuidString)-\(legID.rawValue.uuidString)-\(entry)-\(completion)"
        case .createTrip:
            "create-trip"
        case .addItineraryItem(let tripID):
            "add-itinerary-\(tripID.rawValue.uuidString)"
        case .itineraryTalk(let tripID, let scope):
            "itinerary-talk-\(tripID.rawValue.uuidString)-\(scope)"
        }
    }
}
