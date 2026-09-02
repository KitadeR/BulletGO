import Foundation

nonisolated struct LocalDate: Hashable, Codable, Sendable, Comparable {
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

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
