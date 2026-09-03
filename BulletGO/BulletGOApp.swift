import SwiftData
import SwiftUI

@main
struct BulletGOApp: App {
    @State private var router = AppRouter()
    private let persistence: PersistenceStack

    init() {
        do {
            persistence = try PersistenceStack.live()
        } catch {
            fatalError("Failed to create persistent store: \(error)")
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
