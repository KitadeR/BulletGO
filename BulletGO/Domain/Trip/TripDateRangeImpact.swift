import Foundation

nonisolated struct TripDateRangeImpact: Hashable, Sendable {
    var items: [TripTimelineItem]

    var isEmpty: Bool { items.isEmpty }

    static func outOfRangeItems(in trip: Trip, start: LocalDate, end: LocalDate) -> TripDateRangeImpact {
        var items: [TripTimelineItem] = []
        for item in trip.timeline where isOutOfRange(item, in: trip, start: start, end: end) {
            items.append(item)
        }
        return TripDateRangeImpact(items: items)
    }

    static func displayName(for item: TripTimelineItem, in trip: Trip) -> String {
        switch item {
        case .leg(let id):
            guard let leg = trip.legs.first(where: { $0.id == id }) else { return "" }
            return [leg.origin.value, leg.destination.value]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " → ")
        case .stay(let id):
            return trip.stays.first(where: { $0.id == id })?.place.value ?? ""
        case .activity(let id):
            return trip.activities.first(where: { $0.id == id })?.title.value
                ?? trip.activities.first(where: { $0.id == id })?.place.value
                ?? ""
        }
    }

    private static func isOutOfRange(
        _ item: TripTimelineItem,
        in trip: Trip,
        start: LocalDate,
        end: LocalDate
    ) -> Bool {
        let dates: [LocalDate]
        switch item {
        case .leg(let id):
            guard let leg = trip.legs.first(where: { $0.id == id }) else { return false }
            dates = [leg.scheduledAt.value?.date, leg.arrivesAt.value?.date].compactMap { $0 }
        case .stay(let id):
            guard let stay = trip.stays.first(where: { $0.id == id }) else { return false }
            dates = stay.occupancyDates()
        case .activity(let id):
            guard let activity = trip.activities.first(where: { $0.id == id }) else { return false }
            dates = [activity.scheduledAt.value?.date, activity.endsAt.value?.date].compactMap { $0 }
        }
        return dates.contains { $0 < start || $0 > end }
    }
}
