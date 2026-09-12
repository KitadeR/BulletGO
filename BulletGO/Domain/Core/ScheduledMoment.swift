import Foundation

nonisolated struct ScheduledMoment: Hashable, Codable, Sendable {
    let date: LocalDate
    let time: LocalTime?
    let timeZoneIdentifier: String
    let endTime: LocalTime?
    let isAllDay: Bool

    init(
        date: LocalDate,
        time: LocalTime? = nil,
        timeZoneIdentifier: String,
        endTime: LocalTime? = nil,
        isAllDay: Bool = false
    ) throws {
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw DomainError.invalidTimeZone(timeZoneIdentifier)
        }
        self.date = date
        self.time = isAllDay ? nil : time
        self.timeZoneIdentifier = timeZoneIdentifier
        self.endTime = isAllDay ? nil : endTime
        self.isAllDay = isAllDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            date: try container.decode(LocalDate.self, forKey: .date),
            time: try container.decodeIfPresent(LocalTime.self, forKey: .time),
            timeZoneIdentifier: try container.decode(String.self, forKey: .timeZoneIdentifier),
            endTime: try container.decodeIfPresent(LocalTime.self, forKey: .endTime),
            isAllDay: try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(isAllDay, forKey: .isAllDay)
    }

    func replacingDate(_ newDate: LocalDate) throws -> ScheduledMoment {
        try ScheduledMoment(
            date: newDate,
            time: time,
            timeZoneIdentifier: timeZoneIdentifier,
            endTime: endTime,
            isAllDay: isAllDay
        )
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case time
        case timeZoneIdentifier
        case endTime
        case isAllDay
    }
}
