import Foundation

nonisolated enum AppTab: String, Hashable, CaseIterable, Identifiable, Sendable {
    case home
    case trips
    case you

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .home:
            LocalizedStringResource("Home", comment: "Tab title for the contextual Home screen.")
        case .trips:
            LocalizedStringResource("Trips", comment: "Tab title for the full-trip itinerary.")
        case .you:
            LocalizedStringResource("You", comment: "Tab title for traveler information.")
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .trips:
            "map"
        case .you:
            "person.crop.circle"
        }
    }
}
