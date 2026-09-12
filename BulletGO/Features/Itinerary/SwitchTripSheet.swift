import SwiftUI

struct SwitchTripSheet: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    @State private var pendingDelete: Trip?
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.trips, id: \.id) { trip in
                    Button {
                        Task {
                            await session.selectTrip(id: trip.id)
                            router.dismissPresentation()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: trip.name.value ?? String(localized: "Untitled trip"))
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundStyle(DesignTokens.Color.primaryText)
                                if let dates = TripContentResolver.tripDatesText(trip) {
                                    Text(verbatim: dates)
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundStyle(DesignTokens.Color.secondaryText)
                                }
                            }
                            Spacer()
                            if trip.id == session.trip?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(DesignTokens.Color.tint)
                            }
                        }
                        .frame(minHeight: DesignTokens.TapTarget.minimum)
                    }
                    .accessibilityIdentifier(AccessibilityID.tripSwitcherRow)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            pendingDelete = trip
                        }
                    }
                    .contextMenu {
                        Button("Edit") {
                            router.present(.editTrip(trip.id))
                        }
                        Button("Delete", role: .destructive) {
                            pendingDelete = trip
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.dismissPresentation() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New") { router.present(.createTrip) }
                }
            }
            .overlay {
                if session.trips.isEmpty {
                    ContentUnavailableView("No trips yet", systemImage: "map")
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.tripSwitcher)
        .confirmationDialog(
            "Delete this trip?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete trip", role: .destructive) {
                guard let pendingDelete else { return }
                Task { await delete(pendingDelete) }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This removes the trip and its itinerary from this device.")
        }
    }

    private func delete(_ trip: Trip) async {
        isDeleting = true
        defer { isDeleting = false }
        _ = try? await session.deleteTrip(id: trip.id)
        pendingDelete = nil
        if session.trips.isEmpty {
            router.dismissPresentation()
        }
    }
}
