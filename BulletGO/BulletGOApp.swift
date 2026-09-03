import SwiftData
import SwiftUI

@main
struct BulletGOApp: App {
    @State private var router = AppRouter()
    private let persistence: PersistenceStack
    private let tripStore: TripStore

    init() {
        do {
            let persistence = try PersistenceStack.live()
            let catalog = try QuestionCatalogLoader.loadProduction(from: .main)
            let pack = try PackLoader.loadProduction(from: .main)
            self.persistence = persistence
            self.tripStore = TripStore(
                repository: persistence.repository,
                brain: TripBrain(catalog: catalog, pack: pack, clock: .system)
            )
        } catch {
            fatalError("Failed to create app dependencies: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
                .environment(\.featureRegistry, .production)
                .task {
                    do {
                        try await persistence.bootstrap()
                    } catch {
                        assertionFailure("Failed to seed reference trip: \(error)")
                    }
                }
        }
        .modelContainer(persistence.container)
    }
}
