import Foundation

nonisolated enum JourneyVisualKind: Equatable, Sendable {
    case shinkansen
    case airplane
    case localTrain
    case cityStay
    case generic
    case japanMap
}

nonisolated enum JourneyVisualProvider {
    static func kind(for leg: Leg) -> JourneyVisualKind {
        guard leg.transportMode.status == .confirmed, let mode = leg.transportMode.value else {
            return .generic
        }
        switch mode {
        case .shinkansen:
            return .shinkansen
        case .airplane:
            return .airplane
        case .localTrain:
            return .localTrain
        case .other:
            return .generic
        }
    }

    static func kind(for stay: Stay) -> JourneyVisualKind {
        _ = stay
        return .cityStay
    }

    static func kind(for activity: Activity) -> JourneyVisualKind {
        _ = activity
        return .cityStay
    }
}
