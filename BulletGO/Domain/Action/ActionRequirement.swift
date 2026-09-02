import Foundation

nonisolated enum ActionImportance: String, Hashable, Codable, Sendable {
    case mustDo
    case shouldDo
    case checkRequired
    case optional
    case noAction
}

nonisolated struct ActionRequirement: Hashable, Codable, Sendable {
    let id: ActionRequirementID
    var purposeKey: String
    var importance: ActionImportance
    var relatedPolicyID: PolicyID?
    var requiredStateSummary: String
    var completionCondition: String
}
