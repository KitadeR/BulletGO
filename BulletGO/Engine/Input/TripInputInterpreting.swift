import Foundation

nonisolated enum TripInputIntent: Hashable, Sendable {
    case shinkansen
    case shinkansenWithFujiView
}

nonisolated struct TripInputInterpretation: Hashable, Sendable {
    var mutations: [TripMutation]
    var recognizedIntent: TripInputIntent?
    var fallbackToStructuredQuestions: Bool

    static let empty = TripInputInterpretation(
        mutations: [],
        recognizedIntent: nil,
        fallbackToStructuredQuestions: true
    )
}

nonisolated protocol TripInputInterpreting: Sendable {
    func interpret(_ text: String, trip: Trip, legID: LegID) -> TripInputInterpretation
}

nonisolated struct LocalDeterministicTripInputInterpreter: TripInputInterpreting {
    func interpret(_ text: String, trip: Trip, legID: LegID) -> TripInputInterpretation {
        let normalized = Self.normalized(text)
        guard !normalized.isEmpty else {
            return .empty
        }

        let mentionsShinkansen = Self.containsShinkansen(normalized)
        let mentionsFuji = Self.containsFuji(normalized)
        guard mentionsShinkansen else {
            return .empty
        }

        var mutations: [TripMutation] = [
            .setTransportMode(legID, .shinkansen),
        ]
        if mentionsFuji {
            mutations.append(.setSeatPreference(legID, .mountFujiView))
        }
        return TripInputInterpretation(
            mutations: mutations,
            recognizedIntent: mentionsFuji ? .shinkansenWithFujiView : .shinkansen,
            fallbackToStructuredQuestions: false
        )
    }

    private static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsShinkansen(_ text: String) -> Bool {
        text.contains("shinkansen")
            || text.contains("bullet train")
            || text.contains("しんかんせん")
            || text.contains("ひんかんせん")
            || text.contains("新幹線")
    }

    private static func containsFuji(_ text: String) -> Bool {
        text.contains("fuji")
            || text.contains("富士")
            || text.contains("ふじ")
    }
}
