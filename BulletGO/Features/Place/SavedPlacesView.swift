import SwiftUI

struct SavedPlacesView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    @State private var draftName = ""
    @State private var search = MapKitPlaceSearch()
    @State private var selectedPlace: PlaceReference?

    var body: some View {
        Form {
            PlaceSearchField(
                title: "Place name",
                text: $draftName,
                search: search,
                onSelect: { selectedPlace = $0 }
            )
            Button("Save place") {
                Task { await savePlace() }
            }
            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Section("Saved") {
                ForEach(savedPlaces) { place in
                    Button {
                        router.present(.guidedAdd(tripID, .activity, initialDate: nil, seedPlace: place.place))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: place.place.name)
                            if let address = place.place.address, !address.isEmpty {
                                Text(verbatim: address)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Color.secondaryText)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task {
                                _ = await session.process(.applyMutation(.removeSavedPlace(place.id)))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved places")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.savedPlaces)
    }

    private var savedPlaces: [SavedPlace] {
        session.trip?.savedPlaces ?? []
    }

    private func savePlace() async {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let reference = selectedPlace ?? .manual(name: name)
        let saved = SavedPlace(id: SavedPlaceID(), place: reference, note: nil, createdAt: session.now)
        if await session.process(.applyMutation(.addSavedPlace(saved))) != nil {
            draftName = ""
            selectedPlace = nil
        }
    }
}
