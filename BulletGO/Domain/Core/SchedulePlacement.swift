import Foundation

nonisolated enum SchedulePlacement: Hashable, Sendable {
    case unscheduled
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
        if isAllDay {
            return .allDay(date)
        }
        if time != nil, let endTime {
            do {
                let end = try ScheduledMoment(
                    date: date,
                    time: endTime,
                    timeZoneIdentifier: timeZoneIdentifier,
                    endTime: nil,
                    isAllDay: false
                )
                return .range(start: self, end: end)
            } catch {
                return .start(self)
            }
        }
        if time != nil {
            return .start(self)
        }
        return .dateOnly(date)
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

extension Stay {
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
