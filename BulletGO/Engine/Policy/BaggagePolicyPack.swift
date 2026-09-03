import Foundation

nonisolated struct PackActionTemplate: Hashable, Codable, Sendable {
    var purposeKey: String
    var importance: ActionImportance
    var requiredStateSummary: String
    var completionCondition: String
}

nonisolated struct PackTaskTemplate: Hashable, Codable, Sendable {
    var contentKey: String
    var type: TripTaskType
    var importance: TaskImportance
    var relevantPhases: [LegPhase]
    var completionCondition: TaskCompletionCondition
}

nonisolated struct PackResult: Hashable, Codable, Sendable {
    var labelKey: String
}

nonisolated struct BaggagePolicyPack: Hashable, Codable, Sendable {
    var id: PolicyID
    var version: String
    var effectiveFrom: LocalDate
    var effectiveUntil: LocalDate?
    var appliesToTransport: [TransportMode]
    var totalSizeUpperBoundInclusiveCM: Double
    var oversizedUpperBoundInclusiveCM: Double
    var resultKey: String
    var sourceURL: URL
    var sourceTitle: String
    var results: [String: PackResult]
    var actionTemplates: [PackActionTemplate]
    var taskTemplates: [PackTaskTemplate]

    enum ReservationRequirement: String, Hashable, Sendable {
        case notRequired = "not_required"
        case required = "required"
        case notAllowed = "not_allowed"
    }

    func requirement(forTotalCM total: Double) -> ReservationRequirement {
        if total <= totalSizeUpperBoundInclusiveCM {
            .notRequired
        } else if total <= oversizedUpperBoundInclusiveCM {
            .required
        } else {
            .notAllowed
        }
    }

    func actionTemplate(purposeKey: String) -> PackActionTemplate? {
        actionTemplates.first { $0.purposeKey == purposeKey }
    }

    func taskTemplate(contentKey: String) -> PackTaskTemplate? {
        taskTemplates.first { $0.contentKey == contentKey }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case effectiveFrom
        case effectiveUntil
        case appliesToTransport
        case totalSizeUpperBoundInclusiveCM
        case oversizedUpperBoundInclusiveCM
        case resultKey
        case sourceURL
        case sourceTitle
        case results
        case actionTemplates
        case taskTemplates
    }

    init(
        id: PolicyID,
        version: String,
        effectiveFrom: LocalDate,
        effectiveUntil: LocalDate?,
        appliesToTransport: [TransportMode],
        totalSizeUpperBoundInclusiveCM: Double,
        oversizedUpperBoundInclusiveCM: Double,
        resultKey: String,
        sourceURL: URL,
        sourceTitle: String,
        results: [String: PackResult],
        actionTemplates: [PackActionTemplate],
        taskTemplates: [PackTaskTemplate]
    ) {
        self.id = id
        self.version = version
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.appliesToTransport = appliesToTransport
        self.totalSizeUpperBoundInclusiveCM = totalSizeUpperBoundInclusiveCM
        self.oversizedUpperBoundInclusiveCM = oversizedUpperBoundInclusiveCM
        self.resultKey = resultKey
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.results = results
        self.actionTemplates = actionTemplates
        self.taskTemplates = taskTemplates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = PolicyID(rawValue: try container.decode(String.self, forKey: .id))
        version = try container.decode(String.self, forKey: .version)
        effectiveFrom = try ISOLocalDate.decode(try container.decode(String.self, forKey: .effectiveFrom))
        if let until = try container.decodeIfPresent(String.self, forKey: .effectiveUntil) {
            effectiveUntil = try ISOLocalDate.decode(until)
        } else {
            effectiveUntil = nil
        }
        appliesToTransport = try container.decode([TransportMode].self, forKey: .appliesToTransport)
        totalSizeUpperBoundInclusiveCM = try container.decode(Double.self, forKey: .totalSizeUpperBoundInclusiveCM)
        oversizedUpperBoundInclusiveCM = try container.decode(Double.self, forKey: .oversizedUpperBoundInclusiveCM)
        resultKey = try container.decode(String.self, forKey: .resultKey)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        sourceTitle = try container.decode(String.self, forKey: .sourceTitle)
        results = try container.decode([String: PackResult].self, forKey: .results)
        actionTemplates = try container.decode([PackActionTemplate].self, forKey: .actionTemplates)
        taskTemplates = try container.decode([PackTaskTemplate].self, forKey: .taskTemplates)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.rawValue, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(ISOLocalDate.encode(effectiveFrom), forKey: .effectiveFrom)
        try container.encodeIfPresent(effectiveUntil.map(ISOLocalDate.encode), forKey: .effectiveUntil)
        try container.encode(appliesToTransport, forKey: .appliesToTransport)
        try container.encode(totalSizeUpperBoundInclusiveCM, forKey: .totalSizeUpperBoundInclusiveCM)
        try container.encode(oversizedUpperBoundInclusiveCM, forKey: .oversizedUpperBoundInclusiveCM)
        try container.encode(resultKey, forKey: .resultKey)
        try container.encode(sourceURL, forKey: .sourceURL)
        try container.encode(sourceTitle, forKey: .sourceTitle)
        try container.encode(results, forKey: .results)
        try container.encode(actionTemplates, forKey: .actionTemplates)
        try container.encode(taskTemplates, forKey: .taskTemplates)
    }
}

nonisolated enum ISOLocalDate {
    static func decode(_ string: String) throws -> LocalDate {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            throw EngineError.invalidPackDate(string)
        }
        do {
            return try LocalDate(year: year, month: month, day: day)
        } catch {
            throw EngineError.invalidPackDate(string)
        }
    }

    static func encode(_ date: LocalDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}
