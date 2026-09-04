import Foundation

nonisolated enum TripPhaseResolver {
    static let calendarTimeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    static func resolve(trip: Trip, today: LocalDate) -> TripPhase {
        guard let start = trip.startDate.value, let end = trip.endDate.value else {
            return .planning
        }
        if today < start {
            return .beforeTrip
        }
        if today > end {
            return .finished
        }
        return .inTrip
    }

    static func resolve(trip: Trip, now: Date, timeZone: TimeZone = calendarTimeZone) -> TripPhase {
        guard let today = try? LocalDate(date: now, timeZone: timeZone) else {
            return .planning
        }
        return resolve(trip: trip, today: today)
    }

    static func today(now: Date, timeZone: TimeZone = calendarTimeZone) -> LocalDate? {
        try? LocalDate(date: now, timeZone: timeZone)
    }

    static func daysUntilStart(from today: LocalDate, start: LocalDate) -> Int? {
        guard today < start else {
            return nil
        }
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let todayDate = today.date(in: utc), let startDate = start.date(in: utc) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.dateComponents([.day], from: todayDate, to: startDate).day
    }
}
