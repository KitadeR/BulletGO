import Foundation

nonisolated enum TravelExperienceLevel: String, Hashable, Codable, Sendable {
    case firstTime
    case someExperience
    case frequent
}

nonisolated struct Traveler: Hashable, Codable, Sendable {
    var preferredLanguage: Slot<String>
    var partySize: Slot<Int>
    var japanTravelExperience: Slot<TravelExperienceLevel>
}
