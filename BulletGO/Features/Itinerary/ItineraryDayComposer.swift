import Foundation

nonisolated struct ItinerarySection: Identifiable, Equatable, Sendable {
    enum ID: Hashable, Sendable {
        case unscheduled
        case day(LocalDate)
    }

    var id: ID
    var title: String
    var rows: [TimelineRow]
}

nonisolated enum ItineraryDayComposer {
    static func sections(for trip: Trip) -> [ItinerarySection] {
        let rows = TimelineRowComposer.rows(for: trip)
        var unscheduled: [TimelineRow] = []
        var days: [LocalDate: [TimelineRow]] = [:]
        var datedCount = 0
        for (index, item) in trip.timeline.enumerated() {
            guard rows.indices.contains(index) else { continue }
            if let date = date(for: item, in: trip) {
                datedCount += 1
                days[date, default: []].append(rows[index])
            } else {
                unscheduled.append(rows[index])
            }
        }

        if datedCount == 0 {
            return [
                ItinerarySection(
                    id: .unscheduled,
                    title: String(localized: "Journey"),
                    rows: rows
                )
            ]
        }

        var sections: [ItinerarySection] = []
        if !unscheduled.isEmpty {
            sections.append(
                ItinerarySection(
                    id: .unscheduled,
                    title: String(localized: "Unscheduled"),
                    rows: unscheduled
                )
            )
        }
        for date in days.keys.sorted() {
            sections.append(
                ItinerarySection(
                    id: .day(date),
                    title: date.displayString,
                    rows: days[date] ?? []
                )
            )
        }
        return sections
    }

    static func date(for item: TripTimelineItem, in trip: Trip) -> LocalDate? {
        switch item {
        case .leg(let id):
            trip.legs.first { $0.id == id }?.scheduledAt.value?.date
        case .stay(let id):
            trip.stays.first { $0.id == id }?.checkIn.value?.date
        case .activity(let id):
            trip.activities.first { $0.id == id }?.scheduledAt.value?.date
        }
    }
}
