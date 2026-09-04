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

nonisolated enum TimelineNowKind: Hashable, Sendable {
    case task(TaskID)
    case resume(LegID)
}

nonisolated struct TimelineNowItem: Identifiable, Equatable, Sendable {
    enum ID: Hashable, Sendable {
        case task(TaskID)
        case resume(LegID)
    }

    var id: ID
    var kind: TimelineNowKind
    var contentKey: String
    var content: ResolvedContent
    var destination: AppRoute?
}

nonisolated enum TimelineNowComposer {
    static func items(for trip: Trip, catalog: QuestionCatalog?) -> [TimelineNowItem] {
        guard let catalog else {
            return []
        }
        switch GuidanceProgressEvaluator.evaluate(trip: trip, catalog: catalog) {
        case .ready:
            let snapshot = TaskDisplayPipeline.snapshot(for: trip)
            return snapshot.now.compactMap { taskID in
                guard let task = trip.tasks.first(where: { $0.id == taskID }) else {
                    return nil
                }
                return TimelineNowItem(
                    id: .task(task.id),
                    kind: .task(task.id),
                    contentKey: task.contentKey,
                    content: TripContentResolver.task(contentKey: task.contentKey),
                    destination: .taskDetail(trip.id, task.id)
                )
            }
        case .needsSetup, .paused:
            guard let legID = trip.focusLegID else {
                return []
            }
            return [
                TimelineNowItem(
                    id: .resume(legID),
                    kind: .resume(legID),
                    contentKey: "resume",
                    content: TripContentResolver.resumeGuidance(trip: trip, legID: legID),
                    destination: nil
                ),
            ]
        case .notStarted:
            return []
        }
    }
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
                    destination: .taskDetail(trip.id, task.id)
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
    case stay(StayID)
    case activity(ActivityID)
}

nonisolated struct TimelineRow: Identifiable, Equatable, Sendable {
    var id: TimelineRowKind
    var title: String
    var subtitle: DisplayText
    var visualKind: JourneyVisualKind
    var isLeg: Bool
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
                    visualKind: JourneyVisualProvider.kind(for: leg),
                    isLeg: true,
                    isCurrent: trip.focusLegID == id,
                    destination: .legDetail(trip.id, id)
                )
            case .stay(let id):
                guard let stay = trip.stays.first(where: { $0.id == id }) else {
                    return nil
                }
                return TimelineRow(
                    id: .stay(id),
                    title: stay.place.value ?? "",
                    subtitle: .verbatim(TripContentResolver.staySubtitle(stay)),
                    visualKind: JourneyVisualProvider.kind(for: stay),
                    isLeg: false,
                    isCurrent: false,
                    destination: .stayDetail(trip.id, id)
                )
            case .activity(let id):
                guard let activity = trip.activities.first(where: { $0.id == id }) else {
                    return nil
                }
                return TimelineRow(
                    id: .activity(id),
                    title: activity.title.value ?? "",
                    subtitle: .verbatim(activity.place.value ?? ""),
                    visualKind: JourneyVisualProvider.kind(for: activity),
                    isLeg: false,
                    isCurrent: false,
                    destination: .activityDetail(trip.id, id)
                )
            }
        }
    }
}
