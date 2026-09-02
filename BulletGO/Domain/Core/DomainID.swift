import Foundation

nonisolated struct DomainID<Tag>: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    init() {
        self.rawValue = UUID()
    }

    var description: String { rawValue.uuidString }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(UUID.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum TripIDTag {}
nonisolated enum LegIDTag {}
nonisolated enum ActivityIDTag {}
nonisolated enum BagIDTag {}
nonisolated enum TaskIDTag {}
nonisolated enum ActionRequirementIDTag {}
nonisolated enum PolicyEvaluationIDTag {}
nonisolated enum ReadinessCheckIDTag {}
nonisolated enum ChangeEventIDTag {}
nonisolated enum ReservationIDTag {}

typealias TripID = DomainID<TripIDTag>
typealias LegID = DomainID<LegIDTag>
typealias ActivityID = DomainID<ActivityIDTag>
typealias BagID = DomainID<BagIDTag>
typealias TaskID = DomainID<TaskIDTag>
typealias ActionRequirementID = DomainID<ActionRequirementIDTag>
typealias PolicyEvaluationID = DomainID<PolicyEvaluationIDTag>
typealias ReadinessCheckID = DomainID<ReadinessCheckIDTag>
typealias ChangeEventID = DomainID<ChangeEventIDTag>
typealias ReservationID = DomainID<ReservationIDTag>
