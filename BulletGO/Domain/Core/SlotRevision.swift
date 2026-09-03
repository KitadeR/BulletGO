import Foundation

nonisolated struct SlotRevision<Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    let value: Value?
    let status: SlotStatus
    let source: SlotSource?
    let collectionTiming: SlotCollectionTiming?
    let presentationTiming: SlotPresentationTiming?
    let changedAt: Date

    init(
        value: Value?,
        status: SlotStatus,
        source: SlotSource?,
        collectionTiming: SlotCollectionTiming? = nil,
        presentationTiming: SlotPresentationTiming? = nil,
        changedAt: Date
    ) {
        self.value = value
        self.status = status
        self.source = source
        self.collectionTiming = collectionTiming
        self.presentationTiming = presentationTiming
        self.changedAt = changedAt
    }
}
