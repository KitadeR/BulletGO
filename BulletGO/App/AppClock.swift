import Foundation

enum AppClock {
    static func make(from environment: [String: String] = ProcessInfo.processInfo.environment) -> EngineClock {
        guard let raw = environment["BULLETGO_FIXED_NOW"] else {
            return .system
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basic = ISO8601DateFormatter()
        if let date = withFraction.date(from: raw) ?? basic.date(from: raw) {
            return .fixed(date)
        }
        return .system
    }
}
