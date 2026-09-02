import Foundation

nonisolated struct LocalTime: Hashable, Codable, Sendable, Comparable {
    let hour: Int
    let minute: Int
    let second: Int

    init(hour: Int, minute: Int, second: Int = 0) throws {
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            throw DomainError.invalidTime(hour: hour, minute: minute, second: second)
        }
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        (lhs.hour, lhs.minute, lhs.second) < (rhs.hour, rhs.minute, rhs.second)
    }
}
