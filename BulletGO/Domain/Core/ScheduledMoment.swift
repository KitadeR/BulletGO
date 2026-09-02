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
}
