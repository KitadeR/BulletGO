import Foundation

nonisolated enum ScheduledMomentComposer {
    static func dateOnly(
        date: LocalDate,
        timeZoneIdentifier: String = TripCalendar.timeZoneIdentifier
    ) throws -> ScheduledMoment {
        try ScheduledMoment(date: date, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func allDay(
        date: LocalDate?,
        timeZoneIdentifier: String = TripCalendar.timeZoneIdentifier
    ) throws -> ScheduledMoment {
        try ScheduledMoment(date: date, timeZoneIdentifier: timeZoneIdentifier, isAllDay: true)
    }

    static func start(
        date: LocalDate?,
        time: LocalTime,
        timeZoneIdentifier: String = TripCalendar.timeZoneIdentifier
    ) throws -> ScheduledMoment {
        try ScheduledMoment(date: date, time: time, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func localDate(from date: Date, timeZone: TimeZone = TripCalendar.timeZone) throws -> LocalDate {
        try LocalDate(date: date, timeZone: timeZone)
    }

    static func localTime(from date: Date, timeZone: TimeZone = TripCalendar.timeZone) throws -> LocalTime {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return try LocalTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    static func combine(date: LocalDate, time: LocalTime, timeZone: TimeZone) -> Date? {
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

    static func moment(
        date: LocalDate?,
        timeFrom picker: Date?,
        includeTime: Bool,
        isAllDay: Bool = false,
        timeZone: TimeZone = TripCalendar.timeZone
    ) throws -> ScheduledMoment? {
        if isAllDay {
            return try allDay(date: date, timeZoneIdentifier: timeZone.identifier)
        }
        let time = includeTime ? try picker.map { try localTime(from: $0, timeZone: timeZone) } : nil
        if date == nil, time == nil {
            return nil
        }
        return try ScheduledMoment(
            date: date,
            time: time,
            timeZoneIdentifier: timeZone.identifier
        )
    }
}

nonisolated enum ScheduleIntervalValidator {
    static func validate(_ trip: Trip) throws {
        for leg in trip.legs {
            try validateOrder(
                start: leg.scheduledAt.value,
                end: leg.arrivesAt.value,
                startConfirmed: leg.scheduledAt.status == .confirmed,
                endConfirmed: leg.arrivesAt.status == .confirmed
            )
        }
        for stay in trip.stays {
            try validateOrder(
                start: stay.checkIn.value,
                end: stay.checkOut.value,
                startConfirmed: stay.checkIn.status == .confirmed,
                endConfirmed: stay.checkOut.status == .confirmed
            )
        }
        for activity in trip.activities {
            try validateOrder(
                start: activity.scheduledAt.value,
                end: activity.endsAt.value,
                startConfirmed: activity.scheduledAt.status == .confirmed,
                endConfirmed: activity.endsAt.status == .confirmed
            )
        }
    }

    static func validateOrder(
        start: ScheduledMoment?,
        end: ScheduledMoment?,
        startConfirmed: Bool,
        endConfirmed: Bool
    ) throws {
        guard startConfirmed, endConfirmed, let start, let end else {
            return
        }
        guard let inverted = isInverted(start: start, end: end) else {
            return
        }
        if inverted {
            throw TripValidationError.invertedItemSchedule
        }
    }

    static func isInverted(start: ScheduledMoment, end: ScheduledMoment) -> Bool? {
        switch (start.date, end.date) {
        case let (startDate?, endDate?) where startDate != endDate:
            return endDate < startDate
        case let (startDate?, endDate?) where startDate == endDate:
            return isTimeInverted(start: start, end: end)
        case (nil, nil):
            return isTimeInverted(start: start, end: end)
        default:
            return nil
        }
    }

    private static func isTimeInverted(start: ScheduledMoment, end: ScheduledMoment) -> Bool? {
        if start.isAllDay || end.isAllDay {
            return false
        }
        guard let startTime = start.time, let endTime = end.time else {
            return nil
        }
        return endTime < startTime
    }
}
