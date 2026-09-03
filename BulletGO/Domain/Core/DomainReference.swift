import Foundation

nonisolated struct PolicyID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let jrShinkansenOversizedBaggage = PolicyID(rawValue: "jr_shinkansen_oversized_baggage")
}

nonisolated struct ProcedureID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

nonisolated struct DecisionPointID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let seatSelection = DecisionPointID(rawValue: "seatSelection")
    static let baggagePolicyEvaluation = DecisionPointID(rawValue: "baggagePolicyEvaluation")
}

nonisolated enum DomainScope: Hashable, Codable, Sendable {
    case trip
    case leg(LegID)
    case activity(ActivityID)
}

nonisolated enum DomainPath: Hashable, Codable, Sendable {
    case trip(TripField)
    case traveler(TravelerField)
    case leg(LegID, LegField)
    case activity(ActivityID, ActivityField)
    case bag(BagID, BagField)
    case task(TaskID)
    case readiness(ReadinessCheckID)
}

nonisolated enum TripField: String, Hashable, Codable, Sendable {
    case name
    case startDate
    case endDate
    case timeline
    case currentContext
}

nonisolated enum TravelerField: String, Hashable, Codable, Sendable {
    case preferredLanguage
    case partySize
    case japanTravelExperience
}

nonisolated enum LegField: String, Hashable, Codable, Sendable {
    case origin
    case destination
    case scheduledAt
    case transportMode
    case partyCount
    case baggagePresence
    case seatPreference
    case bagIDs
    case reservation
    case phase
}

nonisolated enum ActivityField: String, Hashable, Codable, Sendable {
    case title
    case type
    case scheduledAt
    case place
    case reservation
}

nonisolated enum BagField: String, Hashable, Codable, Sendable {
    case kind
    case userDescription
    case perceivedSize
    case dimensions
    case weight
}
