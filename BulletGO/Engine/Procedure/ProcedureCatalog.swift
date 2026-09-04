import Foundation

nonisolated enum ProcedureStepKind: String, Hashable, Codable, Sendable {
    case illustration
    case instruction
    case dimensionInput
    case policyResult
}

nonisolated enum ProcedureIllustrationKind: String, Hashable, Codable, Sendable {
    case includeWheelsAndHandles
}

nonisolated struct ProcedureStep: Hashable, Codable, Sendable, Identifiable {
    var id: String
    var kind: ProcedureStepKind
    var title: String
    var body: String
}

nonisolated struct ProcedureDefinition: Hashable, Codable, Sendable, Identifiable {
    var id: ProcedureID
    var version: Int
    var taskContentKey: String
    var title: String
    var sourceURL: URL
    var illustrationKind: ProcedureIllustrationKind
    var steps: [ProcedureStep]

    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case taskContentKey
        case title
        case sourceURL
        case illustrationKind
        case steps
    }

    init(
        id: ProcedureID,
        version: Int,
        taskContentKey: String,
        title: String,
        sourceURL: URL,
        illustrationKind: ProcedureIllustrationKind,
        steps: [ProcedureStep]
    ) {
        self.id = id
        self.version = version
        self.taskContentKey = taskContentKey
        self.title = title
        self.sourceURL = sourceURL
        self.illustrationKind = illustrationKind
        self.steps = steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = ProcedureID(rawValue: try container.decode(String.self, forKey: .id))
        version = try container.decode(Int.self, forKey: .version)
        taskContentKey = try container.decode(String.self, forKey: .taskContentKey)
        title = try container.decode(String.self, forKey: .title)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        illustrationKind = try container.decode(ProcedureIllustrationKind.self, forKey: .illustrationKind)
        steps = try container.decode([ProcedureStep].self, forKey: .steps)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.rawValue, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(taskContentKey, forKey: .taskContentKey)
        try container.encode(title, forKey: .title)
        try container.encode(sourceURL, forKey: .sourceURL)
        try container.encode(illustrationKind, forKey: .illustrationKind)
        try container.encode(steps, forKey: .steps)
    }
}

nonisolated enum ProcedureCatalog {
    static let productionResourceName = "shinkansen_baggage_measurement_v1"

    static func loadProduction(from bundle: Bundle) throws -> ProcedureDefinition {
        try load(from: bundle, resource: productionResourceName)
    }

    static func load(from bundle: Bundle, resource: String) throws -> ProcedureDefinition {
        try load(
            data: BundleResource.jsonData(
                named: resource,
                in: bundle,
                subdirectories: ["Procedures", "Resources/Procedures", "Fixtures"]
            )
        )
    }

    static func load(data: Data) throws -> ProcedureDefinition {
        let procedure: ProcedureDefinition
        do {
            procedure = try JSONDecoder().decode(ProcedureDefinition.self, from: data)
        } catch {
            throw EngineError.missingResource(productionResourceName)
        }
        try validate(procedure)
        return procedure
    }

    static func validate(_ procedure: ProcedureDefinition) throws {
        guard procedure.id == .shinkansenBaggageMeasurement else {
            throw EngineError.missingResource(procedure.id.rawValue)
        }
        guard procedure.version >= 1 else {
            throw EngineError.invalidCatalogVersion
        }
        guard procedure.taskContentKey == ActionPurpose.captureDimensions else {
            throw EngineError.invalidAnswer(procedure.taskContentKey)
        }
        guard procedure.sourceURL.scheme?.lowercased() == "https" else {
            throw EngineError.packSourceMustBeHTTPS
        }
        guard !procedure.steps.isEmpty else {
            throw EngineError.missingResource(procedure.id.rawValue)
        }
        guard procedure.steps.contains(where: { $0.kind == .dimensionInput }) else {
            throw EngineError.missingResource("dimensionInput")
        }
    }
}
