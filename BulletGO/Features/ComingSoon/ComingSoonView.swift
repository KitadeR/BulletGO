import SwiftUI

struct ComingSoonView: View {
    let feature: AppFeature
    let registry: FeatureRegistry

    private var registration: FeatureRegistration {
        registry.registration(for: feature)
    }

    var body: some View {
        ContentUnavailableView {
            Label(
                "Coming soon",
                systemImage: registration.systemImage
            )
        } description: {
            Text(registration.summary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .accessibilityIdentifier(AccessibilityID.comingSoonView)
        .navigationTitle(registration.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ComingSoonView(feature: .baggageCheck, registry: .production)
    }
}
