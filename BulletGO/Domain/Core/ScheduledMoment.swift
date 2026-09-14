import Foundation

nonisolated struct ScheduledMoment: Hashable, Codable, Sendable {
    let date: LocalDate?
    let time: LocalTime?
    let timeZoneIdentifier: String
    let isAllDay: Bool

    var hasScheduleContent: Bool {
        date != nil || time != nil || isAllDay
    }

    init(
        date: LocalDate? = nil,
        time: LocalTime? = nil,
        timeZoneIdentifier: String,
        isAllDay: Bool = false
    ) throws {
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw DomainError.invalidTimeZone(timeZoneIdentifier)
        }
        let resolvedTime = isAllDay ? nil : time
        guard date != nil || resolvedTime != nil || isAllDay else {
            throw DomainError.invalidScheduledMoment
        }
        self.date = date
        self.time = resolvedTime
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isAllDay = isAllDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            date: try container.decodeIfPresent(LocalDate.self, forKey: .date),
            time: try container.decodeIfPresent(LocalTime.self, forKey: .time),
            timeZoneIdentifier: try container.decode(String.self, forKey: .timeZoneIdentifier),
            isAllDay: try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try container.encode(isAllDay, forKey: .isAllDay)
    }

    func replacingDate(_ newDate: LocalDate?) throws -> ScheduledMoment {
        try ScheduledMoment(
            date: newDate,
            time: time,
            timeZoneIdentifier: timeZoneIdentifier,
            isAllDay: isAllDay
        )
    }

    func clearingDatePreservingTiming() -> ScheduledMoment? {
        guard time != nil || isAllDay else {
            return nil
        }
        return try? ScheduledMoment(
            date: nil,
            time: time,
            timeZoneIdentifier: timeZoneIdentifier,
            isAllDay: isAllDay
        )
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case time
        case timeZoneIdentifier
        case isAllDay
    }
}

nonisolated enum TripCalendar {
    static let timeZoneIdentifier = "Asia/Tokyo"

    static var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 9 * 3600)!
    }
}
