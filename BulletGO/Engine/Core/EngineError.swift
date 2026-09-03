import Foundation

nonisolated enum EngineError: Error, Equatable, Sendable {
    case missingResource(String)
    case invalidCatalogVersion
    case duplicateQuestionID(String)
    case duplicateQuestionPriority(Int)
    case inconsistentQuestion(String)
    case missingQuestionChoices(String)
    case invalidPackID
    case invalidPackVersion
    case invalidPackDate(String)
    case invalidPackDateRange
    case packBoundsOutOfOrder
    case packSourceMustBeHTTPS
    case duplicatePackTemplate(String)
    case missingPackResult(String)
    case unknownQuestion(String)
    case invalidAnswer(String)
    case unknownLeg
    case unknownBag
    case tripNotFound
    case noFocusLeg
    case invalidPhaseTransition
}

nonisolated struct EngineClock: Sendable {
    var now: @Sendable () -> Date

    static let system = EngineClock(now: { Date() })

    static func fixed(_ date: Date) -> EngineClock {
        EngineClock(now: { date })
    }
}
