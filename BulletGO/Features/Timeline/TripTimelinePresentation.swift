import Foundation

nonisolated enum DisplayText: Equatable, Sendable {
    case localized(LocalizedStringResource)
    case verbatim(String)

    static func == (lhs: DisplayText, rhs: DisplayText) -> Bool {
        switch (lhs, rhs) {
        case (.localized(let left), .localized(let right)):
            left.key == right.key
        case (.verbatim(let left), .verbatim(let right)):
            left == right
        default:
            false
        }
    }
}

nonisolated enum TimelineNextKind: Hashable, Sendable {
    case task(TaskID)
    case remembered(DeferredPresentationItem)
}

nonisolated struct TimelineNextItem: Identifiable, Equatable, Sendable {
    enum ID: Hashable, Sendable {
        case task(TaskID)
        case remembered(String, DomainScope)
    }

    var id: ID
    var kind: TimelineNextKind
    var content: ResolvedContent
    var destination: AppRoute?
}

nonisolated enum TimelineNextComposer {
    static func items(for trip: Trip) -> [TimelineNextItem] {
        let display = TaskDisplayPipeline.snapshot(for: trip)
        let deferred = DeferredPresentationProjector.snapshot(for: trip)
        var items: [TimelineNextItem] = []
        for taskID in display.next {
            guard let task = trip.tasks.first(where: { $0.id == taskID }) else {
                continue
            }
            items.append(
                TimelineNextItem(
                    id: .task(task.id),
                    kind: .task(task.id),
                    content: TripContentResolver.task(contentKey: task.contentKey),
                    destination: nil
                )
            )
        }
        for remembered in deferred.next {
            items.append(rememberedItem(remembered, trip: trip))
        }
        return items
    }

    static func rememberedItems(for trip: Trip, legID: LegID) -> [TimelineNextItem] {
        DeferredPresentationProjector.snapshot(for: trip, legID: legID).remembered.map { item in
            rememberedItem(item, trip: trip)
        }
    }

    private static func rememberedItem(
        _ item: DeferredPresentationItem,
        trip: Trip
    ) -> TimelineNextItem {
        let destination: AppRoute?
        if case .leg(let legID) = item.scope {
            destination = .legDetail(trip.id, legID)
        } else {
            destination = nil
        }
        return TimelineNextItem(
            id: .remembered(item.contentKey, item.scope),
            kind: .remembered(item),
            content: TripContentResolver.remembered(item, trip: trip),
            destination: destination
        )
    }
}

nonisolated enum TimelineRowKind: Hashable, Sendable {
    case leg(LegID)
    case activity(ActivityID)
}

nonisolated struct TimelineRow: Identifiable, Equatable, Sendable {
    var id: TimelineRowKind
    var title: String
    var subtitle: DisplayText
    var systemImage: String
    var isCurrent: Bool
    var destination: AppRoute?
}

nonisolated enum TimelineRowComposer {
    static func rows(for trip: Trip) -> [TimelineRow] {
        trip.timeline.compactMap { item in
            switch item {
            case .leg(let id):
                guard let leg = trip.legs.first(where: { $0.id == id }) else {
                    return nil
                }
                let origin = leg.origin.value ?? ""
                let destination = leg.destination.value ?? ""
                return TimelineRow(
                    id: .leg(id),
                    title: "\(origin) → \(destination)",
                    subtitle: .localized(TripContentResolver.transportSummary(for: leg)),
                    systemImage: "arrow.triangle.swap",
                    isCurrent: trip.focusLegID == id,
                    destination: .legDetail(trip.id, id)
                )
            case .activity(let id):
                guard let activity = trip.activities.first(where: { $0.id == id }) else {
                    return nil
                }
                return TimelineRow(
                    id: .activity(id),
                    title: activity.title.value ?? "",
                    subtitle: .verbatim(activity.place.value ?? ""),
                    systemImage: "mappin.and.ellipse",
                    isCurrent: false,
                    destination: nil
                )
            }
        }
    }
}
