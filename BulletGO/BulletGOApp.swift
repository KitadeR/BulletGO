import SwiftUI

@main
struct BulletGOApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
                .environment(\.featureRegistry, .production)
        }
    }
}
