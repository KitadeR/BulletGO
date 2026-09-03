import Foundation

nonisolated struct FeatureContext: Hashable, Sendable {
    var tripID: TripID
    var legID: LegID?
    var taskID: TaskID?

    init(tripID: TripID, legID: LegID? = nil, taskID: TaskID? = nil) {
        self.tripID = tripID
        self.legID = legID
        self.taskID = taskID
    }
}

nonisolated enum FeatureDestinationKind: String, Hashable, Sendable {
    case baggageCheck
}
