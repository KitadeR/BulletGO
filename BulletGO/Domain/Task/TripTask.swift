import Foundation

nonisolated enum TripTaskType: String, Hashable, Codable, Sendable {
    case book
    case check
    case prepare
    case install
    case register
    case navigate
    case use
    case verify
}

nonisolated enum TaskImportance: String, Hashable, Codable, Sendable {
    case required
    case important
    case recommended
    case optional
}

nonisolated enum TaskEvidence: String, Hashable, Codable, Sendable {
    case none
    case userStated
    case screenshotParsed
    case pdfParsed
    case officiallyVerified
}

nonisolated enum TaskCompletionCondition: String, Hashable, Codable, Sendable {
    case userConfirmsDone
    case reservationDocumentUploaded
    case reservationDetailsConfirmed
}

nonisolated struct TripTask: Hashable, Codable, Sendable {
    let id: TaskID
    var contentKey: String
    var type: TripTaskType
    var state: TaskState
    var importance: TaskImportance
    var relevantPhases: [LegPhase]
    var deadline: ScheduledMoment?
    var dependencies: [TaskDependency]
    var evidence: TaskEvidence
    var scope: DomainScope
    var relatedActionID: ActionRequirementID?
    var relatedPolicyID: PolicyID?
    var relatedGuideID: ProcedureID?
    var completionCondition: TaskCompletionCondition
}
