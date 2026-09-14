import Foundation

nonisolated struct LocalDate: Hashable, Codable, Sendable, Comparable, Identifiable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else {
            throw DomainError.invalidDate(year: year, month: month, day: day)
        }
        let validated = calendar.dateComponents([.year, .month, .day], from: date)
        guard validated.year == year, validated.month == month, validated.day == day else {
            throw DomainError.invalidDate(year: year, month: month, day: day)
        }
        self.year = year
        self.month = month
        self.day = day
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            year: try container.decode(Int.self, forKey: .year),
            month: try container.decode(Int.self, forKey: .month),
            day: try container.decode(Int.self, forKey: .day)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(year, forKey: .year)
        try container.encode(month, forKey: .month)
        try container.encode(day, forKey: .day)
    }

    private enum CodingKeys: String, CodingKey {
        case year
        case month
        case day
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var displayString: String {
        String(format: "%04d/%02d/%02d", year, month, day)
    }

    var id: String { displayString }

    init(date: Date, timeZone: TimeZone) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            throw DomainError.invalidDate(year: 0, month: 0, day: 0)
        }
        try self.init(year: year, month: month, day: day)
    }

    func date(in timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    func daysUntil(_ other: LocalDate) -> Int {
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let start = date(in: utc), let end = other.date(in: utc) else {
            return 0
        }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? 0
    }

    func addingDays(_ days: Int) throws -> LocalDate {
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let value = date(in: utc),
              let moved = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: value)
        else {
            throw DomainError.invalidDate(year: year, month: month, day: day)
        }
        return try LocalDate(date: moved, timeZone: utc)
    }

    static func dates(from start: LocalDate, through end: LocalDate) -> [LocalDate] {
        guard start <= end else { return [] }
        var result: [LocalDate] = []
        var current = start
        while current <= end {
            result.append(current)
            guard let next = try? current.addingDays(1) else {
                break
            }
            current = next
            if result.count > 366 {
                break
            }
        }
        return result
    }
}
