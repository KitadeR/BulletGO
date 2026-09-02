import Foundation

nonisolated enum PolicyEvaluationStatus: String, Hashable, Codable, Sendable {
    case unevaluated
    case needsMoreInformation
    case evaluated
    case stale
}

nonisolated struct PolicyEvaluation: Hashable, Codable, Sendable {
    let id: PolicyEvaluationID
    var policyID: PolicyID
    var policyVersion: String
    var effectiveDate: LocalDate?
    var scope: DomainScope
    var bagID: BagID?
    var status: PolicyEvaluationStatus
    var missingFieldPaths: [DomainPath]
    var resultFields: [String: String]
    var evaluatedAt: Date?
}
