import Foundation

nonisolated enum SchedulePlacement: Hashable, Sendable {
    case unscheduled
    case unscheduledAllDay
    case unscheduledStart(LocalTime)
    case dateOnly(LocalDate)
    case allDay(LocalDate)
    case start(ScheduledMoment)
    case range(start: ScheduledMoment, end: ScheduledMoment)
}

nonisolated enum StayPresentationRole: Hashable, Sendable {
    case checkIn
    case staying(night: Int, of: Int)
    case checkOut
}

extension ScheduledMoment {
    var placement: SchedulePlacement {
        if let date {
            if isAllDay {
                return .allDay(date)
            }
            if time != nil {
                return .start(self)
            }
            return .dateOnly(date)
        }
        if isAllDay {
            return .unscheduledAllDay
        }
        if let time {
            return .unscheduledStart(time)
        }
        return .unscheduled
    }
}

extension Slot where Value == ScheduledMoment {
    var placement: SchedulePlacement {
        guard status == .confirmed, let value else {
            return .unscheduled
        }
        return value.placement
    }
}

extension Activity {
    nonisolated var schedulePlacement: SchedulePlacement {
        combinedPlacement(start: scheduledAt, end: endsAt)
    }
}

extension Leg {
    nonisolated var schedulePlacement: SchedulePlacement {
        combinedPlacement(start: scheduledAt, end: arrivesAt)
    }
}

extension Stay {
    nonisolated var schedulePlacement: SchedulePlacement {
        combinedPlacement(start: checkIn, end: checkOut)
    }

    nonisolated func occupancyDates() -> [LocalDate] {
        guard let checkInDate = checkIn.value?.date else {
            return []
        }
        guard let checkOutDate = checkOut.value?.date, checkOutDate >= checkInDate else {
            return [checkInDate]
        }
        return LocalDate.dates(from: checkInDate, through: checkOutDate)
    }

    nonisolated func presentationRole(on date: LocalDate) -> StayPresentationRole? {
        guard let checkInDate = checkIn.value?.date else {
            return nil
        }
        let checkOutDate = checkOut.value?.date
        if date == checkInDate, checkOutDate == checkInDate {
            return .checkIn
        }
        if date == checkInDate {
            return .checkIn
        }
        if let checkOutDate, date == checkOutDate {
            return .checkOut
        }
        if let checkOutDate, date > checkInDate, date < checkOutDate {
            let nights = TripsStayNights.nights(from: checkInDate, to: checkOutDate) ?? 1
            let elapsed = max(LocalDate.dates(from: checkInDate, through: date).count - 1, 1)
            return .staying(night: elapsed, of: max(nights, 1))
        }
        return nil
    }
}

nonisolated enum TripsStayNights {
    static func nights(from checkIn: LocalDate, to checkOut: LocalDate) -> Int? {
        let dates = LocalDate.dates(from: checkIn, through: checkOut)
        let value = dates.count - 1
        return value > 0 ? value : nil
    }
}

private nonisolated func combinedPlacement(
    start: Slot<ScheduledMoment>,
    end: Slot<ScheduledMoment>
) -> SchedulePlacement {
    let startConfirmed = start.status == .confirmed ? start.value : nil
    let endConfirmed = end.status == .confirmed ? end.value : nil
    if let startConfirmed, let endConfirmed, endConfirmed.hasScheduleContent {
        return .range(start: startConfirmed, end: endConfirmed)
    }
    if let startConfirmed {
        return startConfirmed.placement
    }
    if let endConfirmed {
        return endConfirmed.placement
    }
    return .unscheduled
}
