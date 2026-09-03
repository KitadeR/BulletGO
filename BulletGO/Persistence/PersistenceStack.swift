import Foundation
import SwiftData

nonisolated struct PersistenceStack: Sendable {
    let container: ModelContainer
    let repository: SwiftDataTripRepository
    let seeder: ReferenceTripSeeder

    static func live() throws -> PersistenceStack {
        try make(
            configuration: ModelConfiguration(
                "BulletGO",
                schema: Self.schema,
                isStoredInMemoryOnly: false
            )
        )
    }

    static func inMemory(named name: String = UUID().uuidString) throws -> PersistenceStack {
        try make(
            configuration: ModelConfiguration(
                name,
                schema: Self.schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    static func onDisk(url: URL) throws -> PersistenceStack {
        try make(
            configuration: ModelConfiguration(
                schema: Self.schema,
                url: url
            )
        )
    }

    func bootstrap() async throws {
        try await seeder.seedIfNeeded(using: repository)
    }

    private static var schema: Schema {
        Schema(versionedSchema: BulletGOSchemaV1.self)
    }

    private static func make(configuration: ModelConfiguration) throws -> PersistenceStack {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: BulletGOMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            throw PersistenceError.storeCreationFailed
        }
        return PersistenceStack(
            container: container,
            repository: SwiftDataTripRepository(modelContainer: container),
            seeder: ReferenceTripSeeder()
        )
    }
}
