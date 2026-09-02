import Foundation

nonisolated enum SlotStatus: String, Hashable, Codable, Sendable {
    case unknown
    case inferred
    case confirmed
    case skipped
    case negative
    case notApplicable
}

nonisolated enum SlotSource: String, Hashable, Codable, Sendable {
    case userStated
    case aiInferred
    case userConfirmed
    case ruleDerived
    case official
}

nonisolated enum SlotConfidence: String, Hashable, Codable, Sendable {
    case low
    case medium
    case high
}

nonisolated enum SlotCollectionTiming: Hashable, Codable, Sendable {
    case immediate
    case justInTime(DecisionPointID)
}

nonisolated enum SlotPresentationTiming: Hashable, Codable, Sendable {
    case immediate
    case deferred(until: DecisionPointID)
}

nonisolated struct Slot<Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    var value: Value?
    var status: SlotStatus
    var source: SlotSource?
    var confidence: SlotConfidence?
    var collectionTiming: SlotCollectionTiming
    var presentationTiming: SlotPresentationTiming
    var updatedAt: Date
    var revisions: [SlotRevision<Value>]

    init(
        value: Value?,
        status: SlotStatus,
        source: SlotSource?,
        confidence: SlotConfidence?,
        collectionTiming: SlotCollectionTiming,
        presentationTiming: SlotPresentationTiming,
        updatedAt: Date,
        revisions: [SlotRevision<Value>] = []
    ) throws {
        self.value = value
        self.status = status
        self.source = source
        self.confidence = confidence
        self.collectionTiming = collectionTiming
        self.presentationTiming = presentationTiming
        self.updatedAt = updatedAt
        self.revisions = revisions
        try Self.validate(value: value, status: status, source: source)
    }

    static func unknown(
        source: SlotSource? = nil,
        collectionTiming: SlotCollectionTiming = .immediate,
        presentationTiming: SlotPresentationTiming = .immediate,
        updatedAt: Date
    ) throws -> Slot {
        try Slot(
            value: nil,
            status: .unknown,
            source: source,
            confidence: nil,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: updatedAt
        )
    }

    static func inferred(
        value: Value,
        confidence: SlotConfidence = .medium,
        collectionTiming: SlotCollectionTiming = .immediate,
        presentationTiming: SlotPresentationTiming = .immediate,
        updatedAt: Date
    ) throws -> Slot {
        try Slot(
            value: value,
            status: .inferred,
            source: .aiInferred,
            confidence: confidence,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: updatedAt
        )
    }

    static func confirmed(
        value: Value,
        source: SlotSource,
        confidence: SlotConfidence = .high,
        collectionTiming: SlotCollectionTiming = .immediate,
        presentationTiming: SlotPresentationTiming = .immediate,
        updatedAt: Date
    ) throws -> Slot {
        try Slot(
            value: value,
            status: .confirmed,
            source: source,
            confidence: confidence,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: updatedAt
        )
    }

    static func negative(
        value: Value? = nil,
        source: SlotSource = .userStated,
        confidence: SlotConfidence = .high,
        collectionTiming: SlotCollectionTiming = .immediate,
        presentationTiming: SlotPresentationTiming = .immediate,
        updatedAt: Date
    ) throws -> Slot {
        try Slot(
            value: value,
            status: .negative,
            source: source,
            confidence: confidence,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: updatedAt
        )
    }

    static func skipped(
        source: SlotSource? = .userStated,
        collectionTiming: SlotCollectionTiming = .immediate,
        presentationTiming: SlotPresentationTiming = .immediate,
        updatedAt: Date
    ) throws -> Slot {
        try Slot(
            value: nil,
            status: .skipped,
            source: source,
            confidence: nil,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: updatedAt
        )
    }

    static func notApplicable(
        collectionTiming: SlotCollectionTiming = .immediate,
        presentationTiming: SlotPresentationTiming = .immediate,
        updatedAt: Date
    ) throws -> Slot {
        try Slot(
            value: nil,
            status: .notApplicable,
            source: nil,
            confidence: nil,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: updatedAt
        )
    }

    func updating(
        value: Value?,
        status: SlotStatus,
        source: SlotSource?,
        confidence: SlotConfidence?,
        at date: Date
    ) throws -> Slot {
        let revision = SlotRevision(
            value: self.value,
            status: self.status,
            source: self.source,
            changedAt: date
        )
        return try Slot(
            value: value,
            status: status,
            source: source,
            confidence: confidence,
            collectionTiming: collectionTiming,
            presentationTiming: presentationTiming,
            updatedAt: date,
            revisions: revisions + [revision]
        )
    }

    static func validate(value: Value?, status: SlotStatus, source: SlotSource?) throws {
        let hasValue = value != nil
        switch status {
        case .unknown:
            guard !hasValue else {
                throw DomainError.invalidSlotCombination(status: status, source: source, hasValue: hasValue)
            }
            if let source, source != .userStated {
                throw DomainError.invalidSlotCombination(status: status, source: source, hasValue: hasValue)
            }
        case .inferred:
            guard hasValue, source == .aiInferred else {
                throw DomainError.invalidSlotCombination(status: status, source: source, hasValue: hasValue)
            }
        case .confirmed:
            guard hasValue, let source else {
                throw DomainError.invalidSlotCombination(status: status, source: source, hasValue: hasValue)
            }
            guard source != .aiInferred else {
                throw DomainError.confirmedSlotRequiresNonInferredSource
            }
        case .skipped, .notApplicable:
            guard !hasValue else {
                throw DomainError.invalidSlotCombination(status: status, source: source, hasValue: hasValue)
            }
        case .negative:
            guard source == .userStated || source == .userConfirmed else {
                throw DomainError.invalidSlotCombination(status: status, source: source, hasValue: hasValue)
            }
        }
    }
}
