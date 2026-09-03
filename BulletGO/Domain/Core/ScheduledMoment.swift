import Foundation

nonisolated struct ScheduledMoment: Hashable, Codable, Sendable {
    let date: LocalDate
    let time: LocalTime?
    let timeZoneIdentifier: String

    init(date: LocalDate, time: LocalTime? = nil, timeZoneIdentifier: String) throws {
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw DomainError.invalidTimeZone(timeZoneIdentifier)
        }
        self.date = date
        self.time = time
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            date: try container.decode(LocalDate.self, forKey: .date),
            time: try container.decodeIfPresent(LocalTime.self, forKey: .time),
            timeZoneIdentifier: try container.decode(String.self, forKey: .timeZoneIdentifier)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case time
        case timeZoneIdentifier
    }
}
