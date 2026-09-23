import SwiftUI

struct AppRouteDestination: View {
    @Environment(\.featureRegistry) private var registry
    let route: AppRoute

    var body: some View {
        switch route {
        case .comingSoon(let feature):
            ComingSoonView(feature: feature, registry: registry)
        case .bookingMethods(let tripID, let legID):
            BookingMethodListView(tripID: tripID, legID: legID)
        case .bookingMethodSmartEX(let tripID, let legID):
            BookingMethodSmartEXView(tripID: tripID, legID: legID)
        case .bookingMethodComingSoon(let tripID, let legID, let method):
            BookingMethodComingSoonView(tripID: tripID, legID: legID, method: method)
        case .legDetail(let tripID, let legID):
            LegDetailView(tripID: tripID, legID: legID)
        case .stayDetail(let tripID, let stayID):
            StayDetailView(tripID: tripID, stayID: stayID)
        case .activityDetail(let tripID, let activityID):
            ActivityDetailView(tripID: tripID, activityID: activityID)
        case .taskDetail(let tripID, let taskID):
            TaskDetailView(tripID: tripID, taskID: taskID)
        case .baggageCheck(let tripID, let legID, let taskID):
            BaggageCheckView(tripID: tripID, legID: legID, taskID: taskID)
        case .tripMap(let tripID):
            TripMapView(tripID: tripID)
        case .savedPlaces(let tripID):
            SavedPlacesView(tripID: tripID)
        }
    }
}
