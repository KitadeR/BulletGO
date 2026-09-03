import SwiftData
import SwiftUI
import UIKit

@main
struct BulletGOApp: App {
    @State private var router = AppRouter()
    @State private var session: TripSessionModel
    private let persistence: PersistenceStack
    private let isUITesting: Bool

    init() {
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            let persistence = isUITesting ? try PersistenceStack.inMemory() : try PersistenceStack.live()
            let catalog = try QuestionCatalogLoader.loadProduction(from: .main)
            let pack = try PackLoader.loadProduction(from: .main)
            let tripStore = TripStore(
                repository: persistence.repository,
                brain: TripBrain(catalog: catalog, pack: pack, clock: .system)
            )
            self.isUITesting = isUITesting
            self.persistence = persistence
            _session = State(initialValue: TripSessionModel(store: tripStore))
        } catch {
            fatalError("Failed to create app dependencies: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
                .environment(session)
                .environment(\.featureRegistry, .production)
                .task {
                    if isUITesting {
                        UIView.setAnimationsEnabled(false)
                    }
                    do {
                        try await persistence.bootstrap()
                    } catch {
                        assertionFailure("Failed to seed reference trip: \(error)")
                    }
                    await session.load()
                }
        }
        .modelContainer(persistence.container)
    }
}
