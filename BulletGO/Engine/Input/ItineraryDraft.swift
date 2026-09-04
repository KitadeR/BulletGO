import Foundation

nonisolated enum ItineraryDraftKind: String, Codable, Sendable {
    case leg
    case stay
    case activity
    case tripNote
    case baggageHint
}

nonisolated struct ProposedItineraryItem: Hashable, Codable, Sendable {
    var kind: ItineraryDraftKind
    var origin: String?
    var destination: String?
    var place: String?
    var title: String?
    var date: String?
    var time: String?
    var transport: String?
    var checkIn: String?
    var checkOut: String?
    var baggageHint: String?
    var sourceQuote: String
    var confidence: SlotConfidence
}

nonisolated struct ProposedItineraryDraft: Hashable, Codable, Sendable {
    var tripName: String?
    var startDate: String?
    var endDate: String?
    var items: [ProposedItineraryItem]
    var unresolved: [String]
}

nonisolated protocol ItineraryDraftExtracting: Sendable {
    func extract(_ text: String, scope: ItineraryInputScope, trip: Trip) async throws -> ProposedItineraryDraft
}

nonisolated struct UnavailableItineraryDraftExtractor: ItineraryDraftExtracting {
    func extract(_ text: String, scope: ItineraryInputScope, trip: Trip) async throws -> ProposedItineraryDraft {
        throw EngineError.invalidAnswer("Itinerary extraction is unavailable offline. Add the plan manually.")
    }
}
