import SwiftUI

struct TripTimelineView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ContentUnavailableView {
            Label(
                "Your trip will appear here",
                systemImage: "map"
            )
        } description: {
            Text("When a trip is added, you’ll see the whole journey here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .accessibilityIdentifier(AccessibilityID.tripTimelineEmpty)
        .navigationTitle("Trip")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Features", systemImage: "square.grid.2x2") {
                    router.push(.featureHub)
                }
                .accessibilityIdentifier(AccessibilityID.openFeatureHub)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TripTimelineView()
    }
    .environment(AppRouter())
}
