import Foundation

struct ActivityEditDraft: Equatable {
    var title: String
    var placeText: String
    var placeReference: PlaceReference?
    var hasDate: Bool
    var date: Date
    var timing: ActivityTimingChoice
    var startTime: Date
    var endTime: Date

    static func from(_ activity: Activity, now: Date = Date()) -> ActivityEditDraft {
        let scheduled = activity.scheduledAt.value
        let ends = activity.endsAt.value
        let zone = TimeZone(identifier: scheduled?.timeZoneIdentifier ?? TripCalendar.timeZoneIdentifier) ?? TripCalendar.timeZone
        let hasDate = scheduled?.date != nil && activity.scheduledAt.status == .confirmed
        let dateValue = scheduled?.date?.date(in: zone) ?? now
        let timing: ActivityTimingChoice
        if scheduled?.isAllDay == true {
            timing = .allDay
        } else if scheduled?.time != nil, ends?.time != nil || activity.endsAt.status == .confirmed {
            timing = .range
        } else if scheduled?.time != nil {
            timing = .start
        } else {
            timing = .none
        }
        return ActivityEditDraft(
            title: activity.title.value ?? "",
            placeText: activity.place.value ?? "",
            placeReference: activity.placeReference,
            hasDate: hasDate,
            date: dateValue,
            timing: timing,
            startTime: combine(dateValue, scheduled?.time, fallback: now, timeZone: zone),
            endTime: combine(dateValue, ends?.time, fallback: dateValue.addingTimeInterval(3600), timeZone: zone)
        )
    }

    func isDirty(comparedTo activity: Activity) -> Bool {
        let baseline = Self.from(activity, now: date)
        return title != baseline.title
            || placeText != baseline.placeText
            || placeReference != baseline.placeReference
            || hasDate != baseline.hasDate
            || timing != baseline.timing
            || dateComponentsDiffer(date, baseline.date)
            || timeComponentsDiffer(startTime, baseline.startTime)
            || timeComponentsDiffer(endTime, baseline.endTime)
    }

    func mutations(activityID: ActivityID) throws -> [TripMutation] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlace = placeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedPlace.isEmpty else {
            throw DomainError.invalidScheduledMoment
        }
        let place = placeReference.map { reference in
            var updated = reference
            if updated.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.name = trimmedPlace.isEmpty ? trimmedTitle : trimmedPlace
            }
            return updated
        } ?? .manual(name: trimmedPlace.isEmpty ? trimmedTitle : trimmedPlace)
        let start = try composeStart()
        let end = try composeEnd()
        return [
            .updateActivityTitle(activityID, trimmedTitle.isEmpty ? trimmedPlace : trimmedTitle),
            .updateActivityPlace(activityID, place),
            .replaceActivitySchedule(activityID, start: start, end: end),
        ]
    }

    private func composeStart() throws -> ScheduledMoment? {
        let timeZone = TripCalendar.timeZone
        let localDate = hasDate ? try ScheduledMomentComposer.localDate(from: date, timeZone: timeZone) : nil
        switch timing {
        case .none:
            guard let localDate else { return nil }
            return try ScheduledMomentComposer.dateOnly(date: localDate)
        case .allDay:
            return try ScheduledMomentComposer.allDay(date: localDate)
        case .start, .range:
            let time = try ScheduledMomentComposer.localTime(from: startTime, timeZone: timeZone)
            return try ScheduledMomentComposer.start(date: localDate, time: time)
        }
    }

    private func composeEnd() throws -> ScheduledMoment? {
        guard timing == .range else { return nil }
        let timeZone = TripCalendar.timeZone
        let localDate = hasDate ? try ScheduledMomentComposer.localDate(from: date, timeZone: timeZone) : nil
        let time = try ScheduledMomentComposer.localTime(from: endTime, timeZone: timeZone)
        return try ScheduledMomentComposer.start(date: localDate, time: time)
    }
}

struct StayEditDraft: Equatable {
    var placeText: String
    var placeReference: PlaceReference?
    var hasCheckIn: Bool
    var checkIn: Date
    var hasCheckOut: Bool
    var checkOut: Date
    var checkInTime: LocalTime?
    var checkOutTime: LocalTime?
    var checkInIsAllDay: Bool
    var checkOutIsAllDay: Bool

    static func from(_ stay: Stay, now: Date = Date()) -> StayEditDraft {
        let zone = TimeZone(identifier: stay.checkIn.value?.timeZoneIdentifier ?? TripCalendar.timeZoneIdentifier) ?? TripCalendar.timeZone
        return StayEditDraft(
            placeText: stay.place.value ?? "",
            placeReference: stay.placeReference,
            hasCheckIn: stay.checkIn.status == .confirmed && stay.checkIn.value?.date != nil,
            checkIn: stay.checkIn.value?.date?.date(in: zone) ?? now,
            hasCheckOut: stay.checkOut.status == .confirmed && stay.checkOut.value?.date != nil,
            checkOut: stay.checkOut.value?.date?.date(in: zone) ?? now.addingTimeInterval(86_400),
            checkInTime: stay.checkIn.value?.time,
            checkOutTime: stay.checkOut.value?.time,
            checkInIsAllDay: stay.checkIn.value?.isAllDay ?? false,
            checkOutIsAllDay: stay.checkOut.value?.isAllDay ?? false
        )
    }

    func isDirty(comparedTo stay: Stay) -> Bool {
        let baseline = Self.from(stay, now: checkIn)
        return placeText != baseline.placeText
            || placeReference != baseline.placeReference
            || hasCheckIn != baseline.hasCheckIn
            || hasCheckOut != baseline.hasCheckOut
            || dateComponentsDiffer(checkIn, baseline.checkIn)
            || dateComponentsDiffer(checkOut, baseline.checkOut)
    }

    var canSave: Bool {
        !placeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!hasCheckIn || !hasCheckOut || checkOut >= checkIn)
    }

    func mutations(stayID: StayID) throws -> [TripMutation] {
        let trimmed = placeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.invalidScheduledMoment
        }
        let place = placeReference.map { reference in
            var updated = reference
            if updated.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.name = trimmed
            }
            return updated
        } ?? .manual(name: trimmed)
        return [
            .updateStayPlace(stayID, place),
            .replaceStaySchedule(stayID, checkIn: try composeCheckIn(), checkOut: try composeCheckOut()),
        ]
    }

    private func composeCheckIn() throws -> ScheduledMoment? {
        try composeStayMoment(
            hasDate: hasCheckIn,
            dateValue: checkIn,
            time: checkInTime,
            isAllDay: checkInIsAllDay
        )
    }

    private func composeCheckOut() throws -> ScheduledMoment? {
        try composeStayMoment(
            hasDate: hasCheckOut,
            dateValue: checkOut,
            time: checkOutTime,
            isAllDay: checkOutIsAllDay
        )
    }
}

struct LegEditDraft: Equatable {
    var originText: String
    var originPlace: PlaceReference?
    var destinationText: String
    var destinationPlace: PlaceReference?
    var hasDate: Bool
    var date: Date
    var hasDepartureTime: Bool
    var departureTime: Date
    var hasArrivalTime: Bool
    var arrivalTime: Date
    var arrivalDayOffset: Int

    static func from(_ leg: Leg, now: Date = Date()) -> LegEditDraft {
        let zone = TimeZone(identifier: leg.scheduledAt.value?.timeZoneIdentifier ?? TripCalendar.timeZoneIdentifier) ?? TripCalendar.timeZone
        let dateValue = leg.scheduledAt.value?.date?.date(in: zone) ?? now
        let arrivalOffset: Int = {
            guard let departure = leg.scheduledAt.value?.date, let arrival = leg.arrivesAt.value?.date else {
                return 0
            }
            return departure.daysUntil(arrival)
        }()
        let arrivalDate = (try? leg.scheduledAt.value?.date?.addingDays(arrivalOffset)) ?? leg.arrivesAt.value?.date
        return LegEditDraft(
            originText: leg.origin.value ?? "",
            originPlace: leg.originPlace,
            destinationText: leg.destination.value ?? "",
            destinationPlace: leg.destinationPlace,
            hasDate: leg.scheduledAt.status == .confirmed && leg.scheduledAt.value?.date != nil,
            date: dateValue,
            hasDepartureTime: leg.scheduledAt.value?.time != nil,
            departureTime: combine(dateValue, leg.scheduledAt.value?.time, fallback: now, timeZone: zone),
            hasArrivalTime: leg.arrivesAt.value?.time != nil,
            arrivalTime: combine(
                arrivalDate?.date(in: zone) ?? dateValue,
                leg.arrivesAt.value?.time,
                fallback: now.addingTimeInterval(3600),
                timeZone: zone
            ),
            arrivalDayOffset: arrivalOffset
        )
    }

    func isDirty(comparedTo leg: Leg) -> Bool {
        let baseline = Self.from(leg, now: date)
        return originText != baseline.originText
            || originPlace != baseline.originPlace
            || destinationText != baseline.destinationText
            || destinationPlace != baseline.destinationPlace
            || hasDate != baseline.hasDate
            || hasDepartureTime != baseline.hasDepartureTime
            || hasArrivalTime != baseline.hasArrivalTime
            || dateComponentsDiffer(date, baseline.date)
            || timeComponentsDiffer(departureTime, baseline.departureTime)
            || timeComponentsDiffer(arrivalTime, baseline.arrivalTime)
    }

    func shiftingDate(to newDate: Date) -> LegEditDraft {
        var copy = self
        copy.date = newDate
        return copy
    }

    func mutations(legID: LegID) throws -> [TripMutation] {
        let originName = originText.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationName = destinationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originName.isEmpty, !destinationName.isEmpty else {
            throw DomainError.invalidScheduledMoment
        }
        return [
            .updateLegOrigin(legID, resolvedPlace(originPlace, name: originName)),
            .updateLegDestination(legID, resolvedPlace(destinationPlace, name: destinationName)),
            .replaceLegSchedule(legID, departure: try composeDeparture(), arrival: try composeArrival()),
        ]
    }

    private func composeDeparture() throws -> ScheduledMoment? {
        let timeZone = TripCalendar.timeZone
        let localDate = hasDate ? try ScheduledMomentComposer.localDate(from: date, timeZone: timeZone) : nil
        if hasDepartureTime {
            let time = try ScheduledMomentComposer.localTime(from: departureTime, timeZone: timeZone)
            return try ScheduledMomentComposer.start(date: localDate, time: time)
        }
        guard let localDate else { return nil }
        return try ScheduledMomentComposer.dateOnly(date: localDate)
    }

    private func composeArrival() throws -> ScheduledMoment? {
        guard hasArrivalTime else { return nil }
        let timeZone = TripCalendar.timeZone
        let localDate: LocalDate?
        if hasDate {
            let departureDate = try ScheduledMomentComposer.localDate(from: date, timeZone: timeZone)
            localDate = try departureDate.addingDays(arrivalDayOffset)
        } else {
            localDate = nil
        }
        let time = try ScheduledMomentComposer.localTime(from: arrivalTime, timeZone: timeZone)
        return try ScheduledMomentComposer.start(date: localDate, time: time)
    }
}

struct TripEditDraft: Equatable {
    var name: String
    var startDate: Date
    var endDate: Date

    static func from(_ trip: Trip, now: Date = Date()) -> TripEditDraft {
        TripEditDraft(
            name: trip.name.value ?? "Japan trip",
            startDate: trip.startDate.value?.date(in: TripCalendar.timeZone) ?? now,
            endDate: trip.endDate.value?.date(in: TripCalendar.timeZone)
                ?? Calendar(identifier: .gregorian).date(byAdding: .day, value: 7, to: now)
                ?? now
        )
    }

    func isDirty(comparedTo trip: Trip) -> Bool {
        let baseline = Self.from(trip, now: startDate)
        return name != baseline.name
            || dateComponentsDiffer(startDate, baseline.startDate)
            || dateComponentsDiffer(endDate, baseline.endDate)
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startDate <= endDate
    }

    func localDates() throws -> (LocalDate, LocalDate) {
        (
            try ScheduledMomentComposer.localDate(from: startDate, timeZone: TripCalendar.timeZone),
            try ScheduledMomentComposer.localDate(from: endDate, timeZone: TripCalendar.timeZone)
        )
    }

    func impact(in trip: Trip) throws -> TripDateRangeImpact {
        let dates = try localDates()
        return TripDateRangeImpact.outOfRangeItems(in: trip, start: dates.0, end: dates.1)
    }

    func mutations(handling: TripDateRangeHandling) throws -> [TripMutation] {
        let dates = try localDates()
        return [
            .setTripName(name.trimmingCharacters(in: .whitespacesAndNewlines)),
            .setTripDateRange(start: dates.0, end: dates.1, handling: handling),
        ]
    }
}

private func composeStayMoment(
    hasDate: Bool,
    dateValue: Date,
    time: LocalTime?,
    isAllDay: Bool
) throws -> ScheduledMoment? {
    let localDate = hasDate ? try ScheduledMomentComposer.localDate(from: dateValue, timeZone: TripCalendar.timeZone) : nil
    if isAllDay {
        return try ScheduledMomentComposer.allDay(date: localDate)
    }
    if let time {
        return try ScheduledMomentComposer.start(date: localDate, time: time)
    }
    guard let localDate else { return nil }
    return try ScheduledMomentComposer.dateOnly(date: localDate)
}

private func resolvedPlace(_ reference: PlaceReference?, name: String) -> PlaceReference {
    guard var reference else {
        return .manual(name: name)
    }
    if reference.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        reference.name = name
    }
    return reference
}

private func combine(_ date: Date, _ time: LocalTime?, fallback: Date, timeZone: TimeZone) -> Date {
    guard let time else { return fallback }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = time.hour
    components.minute = time.minute
    return calendar.date(from: components) ?? fallback
}

private func dateComponentsDiffer(_ lhs: Date, _ rhs: Date) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TripCalendar.timeZone
    return calendar.dateComponents([.year, .month, .day], from: lhs)
        != calendar.dateComponents([.year, .month, .day], from: rhs)
}

private func timeComponentsDiffer(_ lhs: Date, _ rhs: Date) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TripCalendar.timeZone
    return calendar.dateComponents([.hour, .minute], from: lhs)
        != calendar.dateComponents([.hour, .minute], from: rhs)
}
