import Foundation

nonisolated enum BagKind: String, Hashable, Codable, Sendable {
    case suitcase
    case backpack
    case other
}

nonisolated enum PerceivedSize: String, Hashable, Codable, Sendable {
    case small
    case medium
    case large
}

nonisolated struct Bag: Hashable, Codable, Sendable {
    let id: BagID
    var kind: Slot<BagKind>
    var userDescription: Slot<String>
    var perceivedSize: Slot<PerceivedSize>
    var dimensions: Slot<BaggageDimensions>
    var weightKilograms: Slot<Double>
    let createdAt: Date
}
