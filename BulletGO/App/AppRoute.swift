import Foundation

nonisolated enum AppRoute: Hashable, Sendable {
    case comingSoon(AppFeature)
    case legDetail(TripID, LegID)
    case taskDetail(TripID, TaskID)
    case baggageCheck(TripID, LegID, TaskID)
}

nonisolated enum GuidanceEntry: Hashable, Sendable {
    case compose
    case resume
}

nonisolated enum AppPresentation: Hashable, Identifiable, Sendable {
    case guidance(TripID, LegID, GuidanceEntry)

    var id: String {
        switch self {
        case .guidance(let tripID, let legID, let entry):
            "guidance-\(tripID.rawValue.uuidString)-\(legID.rawValue.uuidString)-\(entry)"
        }
    }
}
