import Foundation

nonisolated struct LocalDeterministicItineraryDraftExtractor: ItineraryDraftExtracting {
    func extract(_ text: String, scope: ItineraryInputScope, trip: Trip) async throws -> ProposedItineraryDraft {
        let lowered = text.lowercased()
        var items: [ProposedItineraryItem] = []
        var unresolved: [String] = []

        if let item = legItem(from: text, lowered: lowered) {
            items.append(item)
        }
        if let item = stayItem(from: text, lowered: lowered) {
            items.append(item)
        }
        if lowered.contains("usj") || lowered.contains("universal studios") {
            items.append(
                ProposedItineraryItem(
                    kind: .activity,
                    origin: nil,
                    destination: nil,
                    place: "Osaka",
                    title: "USJ",
                    date: nil,
                    time: nil,
                    transport: nil,
                    checkIn: nil,
                    checkOut: nil,
                    baggageHint: nil,
                    sourceQuote: sourceQuote(in: text, candidates: ["USJ", "Universal Studios"]),
                    confidence: .medium
                )
            )
        }
        if lowered.contains("suitcase") || lowered.contains("luggage") || text.contains("荷物") {
            items.append(
                ProposedItineraryItem(
                    kind: .baggageHint,
                    origin: nil,
                    destination: nil,
                    place: nil,
                    title: nil,
                    date: nil,
                    time: nil,
                    transport: nil,
                    checkIn: nil,
                    checkOut: nil,
                    baggageHint: "large luggage",
                    sourceQuote: sourceQuote(in: text, candidates: ["suitcase", "luggage", "荷物"]),
                    confidence: .medium
                )
            )
        }
        if items.isEmpty {
            unresolved.append("Nothing structured could be taken from this text.")
        }
        return ItineraryDraftValidator.validated(
            ProposedItineraryDraft(tripName: nil, startDate: nil, endDate: nil, items: items, unresolved: unresolved),
            source: text
        )
    }

    private func legItem(from text: String, lowered: String) -> ProposedItineraryItem? {
        let routes: [(String, String, String, String)] = [
            ("Tokyo", "Osaka", "東京", "大阪"),
            ("Tokyo", "Kyoto", "東京", "京都"),
            ("Kyoto", "Osaka", "京都", "大阪"),
        ]
        for (origin, destination, originJA, destinationJA) in routes {
            let hasOrigin = lowered.contains(origin.lowercased()) || text.contains(originJA)
            let hasDestination = lowered.contains(destination.lowercased()) || text.contains(destinationJA)
            if hasOrigin && hasDestination {
                return ProposedItineraryItem(
                    kind: .leg,
                    origin: origin,
                    destination: destination,
                    place: nil,
                    title: nil,
                    date: dateString(in: lowered, original: text),
                    time: lowered.contains("morning") || text.contains("朝") ? "morning" : nil,
                    transport: lowered.contains("shinkansen") || text.contains("新幹線") ? "shinkansen" : nil,
                    checkIn: nil,
                    checkOut: nil,
                    baggageHint: nil,
                    sourceQuote: sourceQuote(in: text, candidates: [origin, destination, originJA, destinationJA]),
                    confidence: .high
                )
            }
        }
        return nil
    }

    private func stayItem(from text: String, lowered: String) -> ProposedItineraryItem? {
        guard lowered.contains("hotel") || lowered.contains("stay") || text.contains("ホテル") else {
            return nil
        }
        let place = lowered.contains("kyoto") || text.contains("京都") ? "Kyoto"
            : lowered.contains("osaka") || text.contains("大阪") ? "Osaka"
            : lowered.contains("tokyo") || text.contains("東京") ? "Tokyo"
            : nil
        return ProposedItineraryItem(
            kind: .stay,
            origin: nil,
            destination: nil,
            place: place,
            title: nil,
            date: nil,
            time: nil,
            transport: nil,
            checkIn: dateString(in: lowered, original: text),
            checkOut: nil,
            baggageHint: nil,
            sourceQuote: sourceQuote(in: text, candidates: ["hotel", "stay", "ホテル"]),
            confidence: .medium
        )
    }

    private func dateString(in lowered: String, original: String) -> String? {
        if lowered.contains("october 2") || lowered.contains("oct 2") || original.contains("10月2") {
            return "2026-10-02"
        }
        if lowered.contains("october 1") || lowered.contains("oct 1") || original.contains("10月1") {
            return "2026-10-01"
        }
        return nil
    }

    private func sourceQuote(in text: String, candidates: [String]) -> String {
        for candidate in candidates {
            if let range = text.range(of: candidate, options: [.caseInsensitive, .diacriticInsensitive]) {
                return String(text[range])
            }
        }
        return String(text.prefix(24))
    }
}
