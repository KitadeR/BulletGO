import Foundation
import SwiftData

@Model
final class SeedStateRecord {
    @Attribute(.unique) var seedKey: String
    var seedVersion: Int
    var appliedAt: Date

    init(seedKey: String, seedVersion: Int, appliedAt: Date) {
        self.seedKey = seedKey
        self.seedVersion = seedVersion
        self.appliedAt = appliedAt
    }
}
