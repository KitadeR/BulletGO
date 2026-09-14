import Foundation

extension Trip {
    nonisolated mutating func invalidateConnectorEstimates(touching item: TripTimelineItem? = nil) {
        if let item {
            connectorEstimates.removeAll { $0.fromItem == item || $0.toItem == item }
        } else {
            connectorEstimates.removeAll()
        }
    }

    nonisolated mutating func pruneConnectorEstimates() {
        let items = Set(timeline)
        connectorEstimates.removeAll { !items.contains($0.fromItem) || !items.contains($0.toItem) }
    }

    nonisolated func connectorCoordinateKey(for item: TripTimelineItem, role: ConnectorAnchorRole) -> String? {
        ConnectorEstimateComposer.coordinate(for: item, in: self, role: role)?.fingerprint
    }
}

nonisolated enum ConnectorAnchorRole: Hashable, Sendable {
    case exit
    case entry
}
