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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            hour: try container.decode(Int.self, forKey: .hour),
            minute: try container.decode(Int.self, forKey: .minute),
            second: try container.decodeIfPresent(Int.self, forKey: .second) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(second, forKey: .second)
    }

    private enum CodingKeys: String, CodingKey {
        case hour
        case minute
        case second
    }

    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        (lhs.hour, lhs.minute, lhs.second) < (rhs.hour, rhs.minute, rhs.second)
    }
}
