import Foundation
import SwiftData

nonisolated enum BulletGOSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TripRecord.self, SeedStateRecord.self]
    }
}
