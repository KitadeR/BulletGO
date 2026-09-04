import Foundation

nonisolated enum PlacePrecision: String, Equatable, Sendable {
    case country
    case city
    case district
    case station
}

nonisolated struct ContextPlacePresentation: Equatable, Sendable {
    var country: String
    var city: String?
    var detail: String?
    var precision: PlacePrecision
    var source: String
}

nonisolated enum PreparationStatusKind: Equatable, Sendable {
    case booked
    case notBooked
    case unverified
    case needsDetail
    case actionRequired
    case ready
}

nonisolated struct PreparationOverviewItem: Identifiable, Equatable, Sendable {
    var id: TimelineRowKind
    var title: String
    var bookingStatus: PreparationStatusKind
    var readinessStatus: PreparationStatusKind
    var destination: AppRoute?
}

nonisolated enum TodayScheduleVisualState: Equatable, Sendable {
    case completed
    case current
    case upcoming
    case neutral
}

nonisolated struct TodayScheduleRow: Identifiable, Equatable, Sendable {
    var id: TimelineRowKind { row.id }
    var row: TimelineRow
    var visualState: TodayScheduleVisualState
    var timeLabel: String?
}

nonisolated struct ContextualHomeSnapshot: Equatable, Sendable {
    var tripPhase: TripPhase
    var tripName: String
    var tripDatesText: String?
    var daysUntilStart: Int?
    var place: ContextPlacePresentation
    var destinations: [String]
    var primaryNow: TimelineNowItem?
    var preparationItems: [PreparationOverviewItem]
    var todayRows: [TodayScheduleRow]
    var upcomingRows: [TimelineRow]
}

nonisolated enum ContextPlaceComposer {
    static let japanCountry = "Japan"

    static func place(for trip: Trip, today: LocalDate) -> ContextPlacePresentation {
        if let fromFocus = place(fromFocus: trip) {
            return fromFocus
        }
        if let fromToday = city(fromToday: trip, today: today) {
            return ContextPlacePresentation(
                country: japanCountry,
                city: fromToday,
                detail: nil,
                precision: .city,
                source: "today_timeline"
            )
        }
        return ContextPlacePresentation(
            country: japanCountry,
            city: nil,
            detail: nil,
            precision: .country,
            source: "country_default"
        )
    }

    private static func place(fromFocus trip: Trip) -> ContextPlacePresentation? {
        switch trip.currentContext.focus {
        case .stay(let id):
            guard let stay = trip.stays.first(where: { $0.id == id }),
                  let city = cleaned(stay.place.value)
            else {
                return nil
            }
            return ContextPlacePresentation(
                country: japanCountry,
                city: city,
                detail: nil,
                precision: .city,
                source: "focus_stay"
            )
        case .activity(let id):
            guard let activity = trip.activities.first(where: { $0.id == id }),
                  let city = cleaned(activity.place.value)
            else {
                return nil
            }
            return ContextPlacePresentation(
                country: japanCountry,
                city: city,
                detail: nil,
                precision: .city,
                source: "focus_activity"
            )
        case .leg(let id):
            guard let leg = trip.legs.first(where: { $0.id == id }) else {
                return nil
            }
            let city: String?
            switch leg.phase {
            case .goingToDeparture, .atDeparture, .boarding:
                city = cleaned(leg.origin.value)
            case .inTransit, .arriving, .completed:
                city = cleaned(leg.destination.value)
            case .planning, .booking, .preparing:
                city = cleaned(leg.destination.value) ?? cleaned(leg.origin.value)
            }
            guard let city else {
                return nil
            }
            return ContextPlacePresentation(
                country: japanCountry,
                city: city,
                detail: nil,
                precision: .city,
                source: "focus_leg"
            )
        case .none:
            return nil
        }
    }

    private static func city(fromToday trip: Trip, today: LocalDate) -> String? {
        for item in trip.timeline {
            guard ItineraryDayComposer.date(for: item, in: trip) == today else {
                continue
            }
            switch item {
            case .stay(let id):
                if let city = cleaned(trip.stays.first(where: { $0.id == id })?.place.value) {
                    return city
                }
            case .activity(let id):
                if let city = cleaned(trip.activities.first(where: { $0.id == id })?.place.value) {
                    return city
                }
            case .leg(let id):
                if let leg = trip.legs.first(where: { $0.id == id }) {
                    if let city = cleaned(leg.destination.value) ?? cleaned(leg.origin.value) {
                        return city
                    }
                }
            }
        }
        return nil
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum HomePrimaryActionComposer {
    static let startSetupContentKey = "start_setup"
    private static let operationalPhases: Set<LegPhase> = [
        .goingToDeparture,
        .atDeparture,
        .boarding,
        .inTransit,
        .arriving,
    ]

    static func primary(
        for trip: Trip,
        catalog: QuestionCatalog?,
        tripPhase: TripPhase
    ) -> TimelineNowItem? {
        if tripPhase == .finished {
            return nil
        }
        let candidates = TimelineNowComposer.items(for: trip, catalog: catalog)
        let visible = candidates.filter { item in
            isVisible(item, in: trip, tripPhase: tripPhase)
        }
        if let first = visible.first {
            return routed(first, trip: trip)
        }
        return startSetupItem(for: trip, catalog: catalog, tripPhase: tripPhase)
    }

    static func destination(for item: TimelineNowItem, trip: Trip?) -> AppRoute? {
        guard let trip else {
            return item.destination
        }
        return routed(item, trip: trip).destination
    }

    static func routed(_ item: TimelineNowItem, trip: Trip) -> TimelineNowItem {
        var routed = item
        if case .task(let taskID) = item.kind,
           let task = trip.tasks.first(where: { $0.id == taskID }),
           task.contentKey == ActionPurpose.captureDimensions,
           task.relatedGuideID == ProcedureID.shinkansenBaggageMeasurement,
           case .leg(let legID) = task.scope
        {
            routed.destination = .baggageCheck(trip.id, legID, task.id)
        }
        return routed
    }

    static func isVisible(
        _ item: TimelineNowItem,
        in trip: Trip,
        tripPhase: TripPhase
    ) -> Bool {
        guard tripPhase == .beforeTrip else {
            return true
        }
        guard case .task(let taskID) = item.kind,
              let task = trip.tasks.first(where: { $0.id == taskID })
        else {
            return true
        }
        guard !task.relevantPhases.isEmpty else {
            return true
        }
        return !task.relevantPhases.allSatisfy(operationalPhases.contains)
    }

    private static func startSetupItem(
        for trip: Trip,
        catalog: QuestionCatalog?,
        tripPhase: TripPhase
    ) -> TimelineNowItem? {
        guard tripPhase != .finished, let catalog, let legID = trip.focusLegID else {
            return nil
        }
        guard case .notStarted = GuidanceProgressEvaluator.evaluate(trip: trip, catalog: catalog) else {
            return nil
        }
        guard QuestionEngine.nextSetupQuestion(in: trip, catalog: catalog) != nil else {
            return nil
        }
        return TimelineNowItem(
            id: .resume(legID),
            kind: .resume(legID),
            contentKey: startSetupContentKey,
            content: ResolvedContent(
                title: LocalizedStringResource(
                    "Update this trip",
                    comment: "Home primary action when setup has not started and questions remain."
                ),
                subtitle: LocalizedStringResource(
                    "A few journey details are still needed.",
                    comment: "Home primary action subtitle for starting itinerary setup."
                ),
                systemImage: "text.badge.plus"
            ),
            destination: nil
        )
    }
}

nonisolated enum PreparationOverviewComposer {
    static func items(for trip: Trip) -> [PreparationOverviewItem] {
        trip.timeline.compactMap { item in
            switch item {
            case .leg(let id):
                guard let leg = trip.legs.first(where: { $0.id == id }) else {
                    return nil
                }
                let origin = leg.origin.value ?? ""
                let destination = leg.destination.value ?? ""
                return PreparationOverviewItem(
                    id: .leg(id),
                    title: "\(origin) → \(destination)",
                    bookingStatus: bookingStatus(leg.reservation),
                    readinessStatus: readinessStatus(for: .leg(id), in: trip),
                    destination: .legDetail(trip.id, id)
                )
            case .stay(let id):
                guard let stay = trip.stays.first(where: { $0.id == id }) else {
                    return nil
                }
                return PreparationOverviewItem(
                    id: .stay(id),
                    title: stay.place.value ?? "",
                    bookingStatus: bookingStatus(stay.reservation),
                    readinessStatus: readinessStatus(for: .stay(id), in: trip),
                    destination: .stayDetail(trip.id, id)
                )
            case .activity(let id):
                guard let activity = trip.activities.first(where: { $0.id == id }) else {
                    return nil
                }
                return PreparationOverviewItem(
                    id: .activity(id),
                    title: activity.title.value ?? "",
                    bookingStatus: bookingStatus(activity.reservation),
                    readinessStatus: readinessStatus(for: .activity(id), in: trip),
                    destination: .activityDetail(trip.id, id)
                )
            }
        }
    }

    static func bookingStatus(_ reservation: Reservation) -> PreparationStatusKind {
        guard reservation.status.status == .confirmed, let status = reservation.status.value else {
            return .unverified
        }
        switch status {
        case .booked:
            return .booked
        case .notBooked:
            return .notBooked
        case .unknown, .cancelled:
            return .unverified
        }
    }

    static func readinessStatus(for scope: DomainScope, in trip: Trip) -> PreparationStatusKind {
        let checks = trip.readinessChecks.filter { $0.scope == scope && !$0.stale }
        guard !checks.isEmpty else {
            return .unverified
        }
        if checks.contains(where: { $0.status == .actionRequired }) {
            return .actionRequired
        }
        if checks.contains(where: { $0.status == .needsMoreInfo }) {
            return .needsDetail
        }
        if checks.allSatisfy({ $0.status == .ready || $0.status == .notApplicable }) {
            return .ready
        }
        return .unverified
    }
}

nonisolated enum TodayScheduleComposer {
    static func rows(
        for trip: Trip,
        today: LocalDate,
        now: Date,
        timeZone: TimeZone
    ) -> [TodayScheduleRow] {
        let section = ItineraryDayComposer.sections(for: trip).first { section in
            if case .day(let date) = section.id {
                return date == today
            }
            return false
        }
        guard let section else {
            return []
        }
        return section.rows.map { row in
            TodayScheduleRow(
                row: row,
                visualState: visualState(for: row, in: trip, now: now, timeZone: timeZone),
                timeLabel: timeLabel(for: row, in: trip)
            )
        }
    }

    static func upcomingRows(for trip: Trip, today: LocalDate, limit: Int = 3) -> [TimelineRow] {
        let dated = ItineraryDayComposer.sections(for: trip).compactMap { section -> (LocalDate, [TimelineRow])? in
            guard case .day(let date) = section.id, date >= today else {
                return nil
            }
            return (date, section.rows)
        }
        return Array(dated.flatMap(\.1).prefix(limit))
    }

    private static func visualState(
        for row: TimelineRow,
        in trip: Trip,
        now: Date,
        timeZone: TimeZone
    ) -> TodayScheduleVisualState {
        if case .leg(let id) = row.id, trip.legs.first(where: { $0.id == id })?.phase == .completed {
            return .completed
        }
        if let moment = scheduledMoment(for: row, in: trip), let time = moment.time {
            let zone = TimeZone(identifier: moment.timeZoneIdentifier) ?? timeZone
            if let momentDate = date(from: moment.date, time: time, timeZone: zone), momentDate < now {
                return .completed
            }
            if row.isCurrent {
                return .current
            }
            return .upcoming
        }
        if row.isCurrent {
            return .current
        }
        return .neutral
    }

    private static func timeLabel(for row: TimelineRow, in trip: Trip) -> String? {
        guard let time = scheduledMoment(for: row, in: trip)?.time else {
            return nil
        }
        return String(format: "%02d:%02d", time.hour, time.minute)
    }

    private static func scheduledMoment(for row: TimelineRow, in trip: Trip) -> ScheduledMoment? {
        switch row.id {
        case .leg(let id):
            let slot = trip.legs.first(where: { $0.id == id })?.scheduledAt
            return slot?.status == .confirmed ? slot?.value : nil
        case .stay(let id):
            let slot = trip.stays.first(where: { $0.id == id })?.checkIn
            return slot?.status == .confirmed ? slot?.value : nil
        case .activity(let id):
            let slot = trip.activities.first(where: { $0.id == id })?.scheduledAt
            return slot?.status == .confirmed ? slot?.value : nil
        }
    }

    private static func date(from date: LocalDate, time: LocalTime, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                year: date.year,
                month: date.month,
                day: date.day,
                hour: time.hour,
                minute: time.minute,
                second: time.second
            )
        )
    }
}

nonisolated enum ContextualHomeComposer {
    static func snapshot(
        for trip: Trip,
        catalog: QuestionCatalog?,
        now: Date,
        timeZone: TimeZone = TripPhaseResolver.calendarTimeZone
    ) -> ContextualHomeSnapshot {
        let today = TripPhaseResolver.today(now: now, timeZone: timeZone)
            ?? (try? LocalDate(year: 1970, month: 1, day: 1))!
        let tripPhase = TripPhaseResolver.resolve(trip: trip, today: today)
        let destinations = uniqueDestinations(in: trip)
        return ContextualHomeSnapshot(
            tripPhase: tripPhase,
            tripName: trip.name.value ?? "",
            tripDatesText: TripContentResolver.tripDatesText(trip),
            daysUntilStart: trip.startDate.value.flatMap {
                TripPhaseResolver.daysUntilStart(from: today, start: $0)
            },
            place: ContextPlaceComposer.place(for: trip, today: today),
            destinations: destinations,
            primaryNow: HomePrimaryActionComposer.primary(
                for: trip,
                catalog: catalog,
                tripPhase: tripPhase
            ),
            preparationItems: PreparationOverviewComposer.items(for: trip),
            todayRows: TodayScheduleComposer.rows(
                for: trip,
                today: today,
                now: now,
                timeZone: timeZone
            ),
            upcomingRows: TodayScheduleComposer.upcomingRows(for: trip, today: today)
        )
    }

    private static func uniqueDestinations(in trip: Trip) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for leg in trip.legs {
            if let destination = cleaned(leg.destination.value), seen.insert(destination).inserted {
                result.append(destination)
            }
        }
        for stay in trip.stays {
            if let place = cleaned(stay.place.value), seen.insert(place).inserted {
                result.append(place)
            }
        }
        return result
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
