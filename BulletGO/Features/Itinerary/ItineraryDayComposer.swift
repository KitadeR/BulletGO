import Foundation

nonisolated struct ItinerarySection: Identifiable, Equatable, Sendable {
    enum ID: Hashable, Sendable {
        case unscheduled
        case day(LocalDate)
    }

    var id: ID
    var title: String
    var rows: [TimelineRow]

    var date: LocalDate? {
        if case .day(let date) = id {
            return date
        }
        return nil
    }
}

nonisolated struct TripsDayOption: Identifiable, Equatable, Sendable {
    var date: LocalDate
    var hasItems: Bool
    var id: LocalDate { date }
}

nonisolated struct TripsTimelineSnapshot: Equatable, Sendable {
    var tripName: String
    var tripDatesText: String?
    var dateOptions: [TripsDayOption]
    var sections: [ItinerarySection]
    var initialDate: LocalDate?
}

nonisolated enum ItineraryDayComposer {
    static func snapshot(
        for trip: Trip,
        now: Date,
        insertingEmptyDay: LocalDate? = nil,
        timeZone: TimeZone = TripPhaseResolver.calendarTimeZone
    ) -> TripsTimelineSnapshot {
        let populatedDates = Set(datedItemDates(in: trip))
        let dateOptions = dateOptions(for: trip).map { date in
            TripsDayOption(date: date, hasItems: populatedDates.contains(date))
        }
        return TripsTimelineSnapshot(
            tripName: trip.name.value ?? "",
            tripDatesText: TripContentResolver.tripDatesText(trip),
            dateOptions: dateOptions,
            sections: sections(for: trip, insertingEmptyDay: insertingEmptyDay),
            initialDate: initialDate(for: trip, now: now, timeZone: timeZone)
        )
    }

    static func sections(for trip: Trip, insertingEmptyDay: LocalDate? = nil) -> [ItinerarySection] {
        let rows = TimelineRowComposer.rows(for: trip)
        var unscheduled: [TimelineRow] = []
        var days: [LocalDate: [TimelineRow]] = [:]
        for (index, item) in trip.timeline.enumerated() {
            guard rows.indices.contains(index) else { continue }
            if let date = date(for: item, in: trip) {
                days[date, default: []].append(rows[index])
            } else {
                unscheduled.append(rows[index])
            }
        }

        var orderedDays = days.keys.sorted()
        if let empty = insertingEmptyDay, days[empty] == nil, dateOptions(for: trip).contains(empty) {
            orderedDays.append(empty)
            orderedDays.sort()
        }

        var sections: [ItinerarySection] = []
        for date in orderedDays {
            sections.append(
                ItinerarySection(
                    id: .day(date),
                    title: date.displayString,
                    rows: days[date] ?? []
                )
            )
        }
        if !unscheduled.isEmpty || sections.isEmpty {
            sections.append(
                ItinerarySection(
                    id: .unscheduled,
                    title: String(localized: "Unscheduled"),
                    rows: unscheduled.isEmpty ? rows : unscheduled
                )
            )
        }
        return sections
    }

    static func dateOptions(for trip: Trip) -> [LocalDate] {
        if let start = trip.startDate.value, let end = trip.endDate.value, start <= end {
            return dates(from: start, through: end)
        }
        return datedItemDates(in: trip)
    }

    static func initialDate(
        for trip: Trip,
        now: Date,
        timeZone: TimeZone = TripPhaseResolver.calendarTimeZone
    ) -> LocalDate? {
        let options = dateOptions(for: trip)
        guard !options.isEmpty else {
            return nil
        }
        let populated = datedItemDates(in: trip)
        let today = TripPhaseResolver.today(now: now, timeZone: timeZone)
        switch TripPhaseResolver.resolve(trip: trip, now: now, timeZone: timeZone) {
        case .beforeTrip:
            return populated.first ?? options.first
        case .inTrip:
            if let today, options.contains(today) {
                return today
            }
            return populated.first ?? options.first
        case .finished:
            return populated.last ?? options.last
        case .planning:
            return populated.first ?? options.first
        }
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

    static func scrollAnchor(for date: LocalDate) -> String {
        String(format: "day-%04d-%02d-%02d", date.year, date.month, date.day)
    }

    static func selectorAnchor(for date: LocalDate) -> String {
        "selector-\(scrollAnchor(for: date))"
    }

    static func scrollAnchor(for section: ItinerarySection) -> String {
        if let date = section.date {
            return scrollAnchor(for: date)
        }
        return "unscheduled"
    }

    static func moveDestination(
        of rowID: TimelineRowKind,
        offset: Int,
        in trip: Trip,
        insertingEmptyDay: LocalDate? = nil
    ) -> (from: Int, to: Int)? {
        let sections = sections(for: trip, insertingEmptyDay: insertingEmptyDay)
        guard let section = sections.first(where: { $0.rows.contains { $0.id == rowID } }),
              let local = section.rows.firstIndex(where: { $0.id == rowID })
        else {
            return nil
        }
        let neighbor = local + offset
        guard section.rows.indices.contains(neighbor),
              let from = timelineIndex(of: rowID, in: trip),
              let neighborIndex = timelineIndex(of: section.rows[neighbor].id, in: trip)
        else {
            return nil
        }
        return (from, offset > 0 ? neighborIndex + 1 : neighborIndex)
    }

    static func timelineIndex(of id: TimelineRowKind, in trip: Trip) -> Int? {
        trip.timeline.firstIndex { item in
            switch (item, id) {
            case (.leg(let lhs), .leg(let rhs)): lhs == rhs
            case (.stay(let lhs), .stay(let rhs)): lhs == rhs
            case (.activity(let lhs), .activity(let rhs)): lhs == rhs
            default: false
            }
        }
    }

    private static func datedItemDates(in trip: Trip) -> [LocalDate] {
        var seen: Set<LocalDate> = []
        var dates: [LocalDate] = []
        for item in trip.timeline {
            guard let date = date(for: item, in: trip), !seen.contains(date) else {
                continue
            }
            seen.insert(date)
            dates.append(date)
        }
        return dates.sorted()
    }

    private static func dates(from start: LocalDate, through end: LocalDate) -> [LocalDate] {
        let utc = TimeZone(secondsFromGMT: 0)!
        var result: [LocalDate] = []
        var current = start
        while current <= end {
            result.append(current)
            guard let value = current.date(in: utc),
                  let moved = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: value),
                  let next = try? LocalDate(date: moved, timeZone: utc)
            else {
                break
            }
            current = next
            if result.count > 366 {
                break
            }
        }
        return result
    }
}
