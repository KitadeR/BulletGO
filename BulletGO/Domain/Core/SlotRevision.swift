import Foundation

nonisolated struct SlotRevision<Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    let value: Value?
    let status: SlotStatus
    let source: SlotSource?
    let changedAt: Date
}
