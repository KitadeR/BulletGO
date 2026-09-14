import Foundation

nonisolated enum TripScopedDataPurger {
    static func purge(scope: DomainScope, from trip: inout Trip) {
        trip.notes.removeAll { $0.scope == scope }
        trip.attachments.removeAll { $0.scope == scope }
        trip.tasks.removeAll { $0.scope == scope }
        trip.readinessChecks.removeAll { $0.scope == scope }
        let item: TripTimelineItem?
        switch scope {
        case .trip:
            item = nil
        case .leg(let id):
            item = .leg(id)
        case .stay(let id):
            item = .stay(id)
        case .activity(let id):
            item = .activity(id)
        }
        if let item {
            trip.connectorEstimates.removeAll { $0.fromItem == item || $0.toItem == item }
        }
    }

    static func captureBundle(for item: TripTimelineItem, in trip: Trip) -> DeletedItineraryItemBundle {
        let scope: DomainScope
        var leg: Leg?
        var stay: Stay?
        var activity: Activity?
        switch item {
        case .leg(let id):
            scope = .leg(id)
            leg = trip.legs.first { $0.id == id }
        case .stay(let id):
            scope = .stay(id)
            stay = trip.stays.first { $0.id == id }
        case .activity(let id):
            scope = .activity(id)
            activity = trip.activities.first { $0.id == id }
        }
        return DeletedItineraryItemBundle(
            item: item,
            timelineIndex: trip.timeline.firstIndex(of: item) ?? trip.timeline.count,
            leg: leg,
            stay: stay,
            activity: activity,
            notes: trip.notes.filter { $0.scope == scope },
            attachments: trip.attachments.filter { $0.scope == scope },
            tasks: trip.tasks.filter { $0.scope == scope },
            readinessChecks: trip.readinessChecks.filter { $0.scope == scope },
            connectors: trip.connectorEstimates.filter { $0.fromItem == item || $0.toItem == item },
            focus: trip.currentContext.focus
        )
    }

    static func restore(_ bundle: DeletedItineraryItemBundle, into trip: inout Trip) throws {
        if let leg = bundle.leg {
            guard !trip.legs.contains(where: { $0.id == leg.id }) else {
                throw TripValidationError.duplicateLegIDs
            }
            trip.legs.append(leg)
        }
        if let stay = bundle.stay {
            guard !trip.stays.contains(where: { $0.id == stay.id }) else {
                throw TripValidationError.duplicateStayIDs
            }
            trip.stays.append(stay)
        }
        if let activity = bundle.activity {
            guard !trip.activities.contains(where: { $0.id == activity.id }) else {
                throw TripValidationError.duplicateActivityIDs
            }
            trip.activities.append(activity)
        }
        let index = min(max(bundle.timelineIndex, 0), trip.timeline.count)
        if !trip.timeline.contains(bundle.item) {
            trip.timeline.insert(bundle.item, at: index)
        }
        for note in bundle.notes where !trip.notes.contains(where: { $0.id == note.id }) {
            trip.notes.append(note)
        }
        for attachment in bundle.attachments where !trip.attachments.contains(where: { $0.id == attachment.id }) {
            trip.attachments.append(attachment)
        }
        for task in bundle.tasks where !trip.tasks.contains(where: { $0.id == task.id }) {
            trip.tasks.append(task)
        }
        for check in bundle.readinessChecks where !trip.readinessChecks.contains(where: { $0.id == check.id }) {
            trip.readinessChecks.append(check)
        }
        for estimate in bundle.connectors where !trip.connectorEstimates.contains(where: {
            $0.fromItem == estimate.fromItem && $0.toItem == estimate.toItem
        }) {
            trip.connectorEstimates.append(estimate)
        }
        trip.currentContext.focus = bundle.focus
    }
}

nonisolated struct DeletedItineraryItemBundle: Hashable, Codable, Sendable {
    var item: TripTimelineItem
    var timelineIndex: Int
    var leg: Leg?
    var stay: Stay?
    var activity: Activity?
    var notes: [ScopedNote]
    var attachments: [AttachmentRecord]
    var tasks: [TripTask]
    var readinessChecks: [ReadinessCheck]
    var connectors: [ConnectorEstimate]
    var focus: CurrentFocus
}
