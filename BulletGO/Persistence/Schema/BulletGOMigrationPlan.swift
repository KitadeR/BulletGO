import Foundation
import SwiftData

nonisolated enum BulletGOMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BulletGOSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
