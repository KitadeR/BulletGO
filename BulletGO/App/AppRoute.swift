import Foundation

nonisolated enum AppRoute: Hashable, Sendable {
    case featureHub
    case comingSoon(AppFeature)
    case legDetail(TripID, LegID)
}
