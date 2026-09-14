import SwiftUI

struct AppPresentationSheet: View {
    var presentation: AppPresentation
    var now: Date

    var body: some View {
        switch presentation {
        case .guidance(let tripID, let legID, let entry, let completion):
            GuidanceFlowView(tripID: tripID, legID: legID, entry: entry, completion: completion)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .createTrip:
            CreateTripSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .editTrip(let tripID):
            CreateTripSheet(tripID: tripID)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .switchTrip:
            SwitchTripSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .guidedAdd(let tripID, let kind, let initialDate, let seedPlace):
            GuidedAddFlowView(
                tripID: tripID,
                kind: kind,
                initialDate: initialDate,
                now: now,
                search: MapKitPlaceSearch(),
                seedPlace: seedPlace
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
