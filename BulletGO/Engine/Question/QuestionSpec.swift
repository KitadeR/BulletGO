import Foundation

nonisolated struct QuestionID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let legDate = QuestionID(rawValue: "q_leg_date")
    static let transport = QuestionID(rawValue: "q_transport")
    static let ticketStatus = QuestionID(rawValue: "q_ticket_status")
    static let selectService = QuestionID(rawValue: "q_select_service")
    static let luggagePresence = QuestionID(rawValue: "q_luggage_presence")
    static let baggageDimensions = QuestionID(rawValue: "q_baggage_dimensions")
}

nonisolated enum QuestionTarget: Hashable, Codable, Sendable {
    case legScheduledAt
    case legTransportMode
    case legReservationStatus
    case legReservationService
    case legBaggagePresence
    case bagDimensions

    var expectedAnswerType: QuestionAnswerType {
        switch self {
        case .legScheduledAt: .scheduledMoment
        case .legTransportMode: .transportMode
        case .legReservationStatus: .reservationStatus
        case .legReservationService: .bookingService
        case .legBaggagePresence: .baggagePresence
        case .bagDimensions: .baggageDimensions
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "legScheduledAt": self = .legScheduledAt
        case "legTransportMode": self = .legTransportMode
        case "legReservationStatus": self = .legReservationStatus
        case "legReservationService": self = .legReservationService
        case "legBaggagePresence": self = .legBaggagePresence
        case "bagDimensions": self = .bagDimensions
        case let value:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown question target \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kindName, forKey: .kind)
    }

    private var kindName: String {
        switch self {
        case .legScheduledAt: "legScheduledAt"
        case .legTransportMode: "legTransportMode"
        case .legReservationStatus: "legReservationStatus"
        case .legReservationService: "legReservationService"
        case .legBaggagePresence: "legBaggagePresence"
        case .bagDimensions: "bagDimensions"
        }
    }
}

nonisolated enum QuestionAnswerType: String, Hashable, Codable, Sendable {
    case scheduledMoment
    case transportMode
    case reservationStatus
    case bookingService
    case baggagePresence
    case baggageDimensions
}

nonisolated enum QuestionUIKind: String, Hashable, Codable, Sendable {
    case dateTime
    case singleChoice
    case dimensions
}

nonisolated enum QuestionCondition: Hashable, Codable, Sendable {
    case always
    case reservationStatusIs(ReservationStatus)
    case transportIs(TransportMode)
    case policyNeedsDimensions

    private enum CodingKeys: String, CodingKey {
        case kind
        case status
        case mode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "always":
            self = .always
        case "reservationStatusIs":
            self = .reservationStatusIs(try container.decode(ReservationStatus.self, forKey: .status))
        case "transportIs":
            self = .transportIs(try container.decode(TransportMode.self, forKey: .mode))
        case "policyNeedsDimensions":
            self = .policyNeedsDimensions
        case let value:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown question condition \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .always:
            try container.encode("always", forKey: .kind)
        case .reservationStatusIs(let status):
            try container.encode("reservationStatusIs", forKey: .kind)
            try container.encode(status, forKey: .status)
        case .transportIs(let mode):
            try container.encode("transportIs", forKey: .kind)
            try container.encode(mode, forKey: .mode)
        case .policyNeedsDimensions:
            try container.encode("policyNeedsDimensions", forKey: .kind)
        }
    }
}

nonisolated struct QuestionChoice: Hashable, Codable, Sendable {
    var value: String
    var labelKey: String
}

nonisolated enum QuestionRole: String, Hashable, Codable, Sendable {
    case setup
    case action

    static func defaultRole(for target: QuestionTarget) -> QuestionRole {
        switch target {
        case .legReservationService, .bagDimensions:
            .action
        case .legScheduledAt, .legTransportMode, .legReservationStatus, .legBaggagePresence:
            .setup
        }
    }
}

nonisolated struct QuestionSpec: Hashable, Codable, Sendable {
    var id: QuestionID
    var priority: Int
    var target: QuestionTarget
    var uiKind: QuestionUIKind
    var answerType: QuestionAnswerType
    var `when`: QuestionCondition
    var choices: [QuestionChoice]
    var role: QuestionRole

    init(
        id: QuestionID,
        priority: Int,
        target: QuestionTarget,
        uiKind: QuestionUIKind,
        answerType: QuestionAnswerType,
        when: QuestionCondition,
        choices: [QuestionChoice],
        role: QuestionRole? = nil
    ) {
        self.id = id
        self.priority = priority
        self.target = target
        self.uiKind = uiKind
        self.answerType = answerType
        self.when = when
        self.choices = choices
        self.role = role ?? .defaultRole(for: target)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case priority
        case target
        case uiKind
        case answerType
        case when
        case choices
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let target = try container.decode(QuestionTarget.self, forKey: .target)
        self.init(
            id: try container.decode(QuestionID.self, forKey: .id),
            priority: try container.decode(Int.self, forKey: .priority),
            target: target,
            uiKind: try container.decode(QuestionUIKind.self, forKey: .uiKind),
            answerType: try container.decode(QuestionAnswerType.self, forKey: .answerType),
            when: try container.decode(QuestionCondition.self, forKey: .when),
            choices: try container.decode([QuestionChoice].self, forKey: .choices),
            role: try container.decodeIfPresent(QuestionRole.self, forKey: .role)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(priority, forKey: .priority)
        try container.encode(target, forKey: .target)
        try container.encode(uiKind, forKey: .uiKind)
        try container.encode(answerType, forKey: .answerType)
        try container.encode(`when`, forKey: .when)
        try container.encode(choices, forKey: .choices)
        try container.encode(role, forKey: .role)
    }
}

nonisolated struct QuestionCatalog: Hashable, Codable, Sendable {
    var catalogVersion: Int
    var questions: [QuestionSpec]

    func spec(id: QuestionID) -> QuestionSpec? {
        questions.first { $0.id == id }
    }
}
