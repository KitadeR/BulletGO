import Foundation

nonisolated struct TripsQuickContextAnchor: Identifiable, Sendable {
    var row: TimelineRow
    var id: TimelineRowKind { row.id }
}

nonisolated struct TripsQuickContextItem: Identifiable, Equatable, Sendable {
    var id: String
    var title: LocalizedStringResource
    var why: LocalizedStringResource?
    var destination: AppRoute?

    static func == (lhs: TripsQuickContextItem, rhs: TripsQuickContextItem) -> Bool {
        lhs.id == rhs.id
            && lhs.title.key == rhs.title.key
            && lhs.why?.key == rhs.why?.key
            && lhs.destination == rhs.destination
    }
}

nonisolated struct TripsQuickContextSnapshot: Equatable, Sendable {
    var title: String
    var metaText: String?
    var heading: LocalizedStringResource?
    var items: [TripsQuickContextItem]
    var detail: AppRoute

    static func == (lhs: TripsQuickContextSnapshot, rhs: TripsQuickContextSnapshot) -> Bool {
        lhs.title == rhs.title
            && lhs.metaText == rhs.metaText
            && lhs.heading?.key == rhs.heading?.key
            && lhs.items == rhs.items
            && lhs.detail == rhs.detail
    }
}

nonisolated enum TripsQuickContextComposer {
    static let itemLimit = 3

    static func snapshot(
        row: TimelineRow,
        trip: Trip,
        catalog: QuestionCatalog?,
        now: Date
    ) -> TripsQuickContextSnapshot? {
        guard let detail = row.destination else {
            return nil
        }
        switch row.id {
        case .leg(let id):
            guard let leg = trip.legs.first(where: { $0.id == id }) else {
                return nil
            }
            return legSnapshot(
                row: row,
                trip: LegDetailComposer.focusedTrip(trip, legID: id),
                leg: leg,
                catalog: catalog,
                now: now,
                detail: detail
            )
        case .activity(let id):
            guard let activity = trip.activities.first(where: { $0.id == id }) else {
                return nil
            }
            return activitySnapshot(row: row, trip: trip, activity: activity, catalog: catalog, detail: detail)
        case .stay(let id, _):
            guard let stay = trip.stays.first(where: { $0.id == id }) else {
                return nil
            }
            return staySnapshot(row: row, trip: trip, stay: stay, catalog: catalog, detail: detail)
        }
    }

    private static func legSnapshot(
        row: TimelineRow,
        trip: Trip,
        leg: Leg,
        catalog: QuestionCatalog?,
        now: Date,
        detail: AppRoute
    ) -> TripsQuickContextSnapshot {
        let items = contextItems(row: row, trip: trip, catalog: catalog)
        let phase = TripPhaseResolver.resolve(trip: trip, now: now)
        let heading: LocalizedStringResource?
        if items.isEmpty {
            heading = nil
        } else if phase == .planning || phase == .beforeTrip {
            heading = LocalizedStringResource(
                "Before departure",
                comment: "Quick Context heading for a journey that is still ahead."
            )
        } else {
            heading = LocalizedStringResource(
                "For this journey",
                comment: "Quick Context heading for a journey during the trip."
            )
        }
        return TripsQuickContextSnapshot(
            title: row.title,
            metaText: legMeta(leg),
            heading: heading,
            items: items,
            detail: detail
        )
    }

    private static func activitySnapshot(
        row: TimelineRow,
        trip: Trip,
        activity: Activity,
        catalog: QuestionCatalog?,
        detail: AppRoute
    ) -> TripsQuickContextSnapshot {
        let items = contextItems(row: row, trip: trip, catalog: catalog)
        let heading: LocalizedStringResource? = items.isEmpty
            ? nil
            : LocalizedStringResource(
                "Before you go",
                comment: "Quick Context heading for an activity."
            )
        return TripsQuickContextSnapshot(
            title: activity.title.value ?? row.title,
            metaText: activityMeta(activity, row: row),
            heading: heading,
            items: items,
            detail: detail
        )
    }

    private static func staySnapshot(
        row: TimelineRow,
        trip: Trip,
        stay: Stay,
        catalog: QuestionCatalog?,
        detail: AppRoute
    ) -> TripsQuickContextSnapshot {
        let items = contextItems(row: row, trip: trip, catalog: catalog)
        return TripsQuickContextSnapshot(
            title: stay.place.value ?? row.title,
            metaText: stayMeta(stay, row: row),
            heading: nil,
            items: items,
            detail: detail
        )
    }

    private static func contextItems(
        row: TimelineRow,
        trip: Trip,
        catalog: QuestionCatalog?
    ) -> [TripsQuickContextItem] {
        var items: [TripsQuickContextItem] = []
        if let setup = setupItem(row: row, trip: trip, catalog: catalog) {
            items.append(setup)
        }
        for taskItem in scopedTaskItems(row: row, trip: trip) {
            if items.count >= itemLimit {
                break
            }
            if items.contains(where: { $0.id == taskItem.id }) {
                continue
            }
            items.append(taskItem)
        }
        return Array(items.prefix(itemLimit))
    }

    private static func setupItem(
        row: TimelineRow,
        trip: Trip,
        catalog: QuestionCatalog?
    ) -> TripsQuickContextItem? {
        guard case .leg(let legID) = row.id, let catalog else {
            return nil
        }
        switch GuidanceProgressEvaluator.evaluate(trip: trip, catalog: catalog) {
        case .ready:
            return nil
        case .notStarted, .needsSetup, .paused:
            let content = TripContentResolver.resumeGuidance(trip: trip, legID: legID)
            return TripsQuickContextItem(
                id: "setup-\(legID.rawValue.uuidString)",
                title: content.title,
                why: content.subtitle,
                destination: .legDetail(trip.id, legID)
            )
        }
    }

    private static func scopedTaskItems(
        row: TimelineRow,
        trip: Trip
    ) -> [TripsQuickContextItem] {
        let snapshot = TaskDisplayPipeline.snapshot(for: trip)
        let orderedIDs = snapshot.now + snapshot.next + snapshot.later
        return orderedIDs.compactMap { taskID -> TripsQuickContextItem? in
            guard let task = trip.tasks.first(where: { $0.id == taskID }),
                  matches(task.scope, row: row)
            else {
                return nil
            }
            let routed = HomePrimaryActionComposer.routed(
                TimelineNowItem(
                    id: .task(task.id),
                    kind: .task(task.id),
                    contentKey: task.contentKey,
                    content: TripContentResolver.task(contentKey: task.contentKey),
                    destination: .taskDetail(trip.id, task.id)
                ),
                trip: trip
            )
            return TripsQuickContextItem(
                id: "task-\(task.contentKey)",
                title: routed.content.title,
                why: TripContentResolver.taskWhyNow(task.contentKey),
                destination: routed.destination
            )
        }
    }

    private static func matches(_ scope: DomainScope, row: TimelineRow) -> Bool {
        switch (scope, row.id) {
        case (.leg(let left), .leg(let right)):
            left == right
        case (.stay(let left), .stay(let right, _)):
            left == right
        case (.activity(let left), .activity(let right)):
            left == right
        default:
            false
        }
    }

    private static func legMeta(_ leg: Leg) -> String? {
        var parts: [String] = []
        if leg.scheduledAt.status == .confirmed,
           let moment = leg.scheduledAt.value,
           !moment.isAllDay,
           let time = moment.time
        {
            parts.append(String(format: "%02d:%02d", time.hour, time.minute))
        }
        if leg.reservation.status.status == .confirmed, leg.reservation.status.value == .booked {
            parts.append(String(localized: LocalizedStringResource(
                "Already booked",
                comment: "Choice for a purchased reservation."
            )))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func activityMeta(_ activity: Activity, row: TimelineRow) -> String? {
        var parts: [String] = []
        if case .exact(let text) = row.gutterDisplay {
            parts.append(text)
        }
        if activity.reservation.status.status == .confirmed, activity.reservation.status.value == .booked {
            parts.append(String(localized: LocalizedStringResource(
                "Already booked",
                comment: "Choice for a purchased reservation."
            )))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func stayMeta(_ stay: Stay, row: TimelineRow) -> String? {
        if case .exact(let text) = row.gutterDisplay {
            return text
        }
        return stay.place.value == row.title ? nil : row.title
    }
}
