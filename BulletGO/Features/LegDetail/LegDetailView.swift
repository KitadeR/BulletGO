import SwiftUI

struct LegDetailView: View {
    @Environment(TripSessionModel.self) private var session
    let tripID: TripID
    let legID: LegID

    var body: some View {
        if session.trip?.id == tripID,
           let leg = session.trip?.legs.first(where: { $0.id == legID }),
           leg.transportMode.value == .shinkansen {
            ShinkansenJourneyView(tripID: tripID, legID: legID)
        } else {
            JourneyConditionView(tripID: tripID, legID: legID)
        }
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
