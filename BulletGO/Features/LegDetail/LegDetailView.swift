import SwiftUI

struct LegDetailView: View {
    let tripID: TripID
    let legID: LegID

    var body: some View {
        JourneyConditionView(tripID: tripID, legID: legID)
    }
}

#if DEBUG
#Preview("Setup") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Ready") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.readyForNow.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
}
#endif
