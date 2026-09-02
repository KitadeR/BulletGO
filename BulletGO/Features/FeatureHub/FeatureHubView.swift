import SwiftUI

struct FeatureHubView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.featureRegistry) private var registry

    var body: some View {
        List(registry.visibleFeatures) { registration in
            Button {
                if let route = registration.navigationRoute {
                    router.push(route)
                }
            } label: {
                FeatureRow(registration: registration)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.featureRow(registration.feature))
        }
        .listStyle(.plain)
        .background(DesignTokens.Color.canvas)
        .accessibilityIdentifier(AccessibilityID.featureHubList)
        .navigationTitle("Features")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        FeatureHubView()
    }
    .environment(AppRouter())
}
