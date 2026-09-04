import Foundation

nonisolated struct RemoteItineraryDraftExtractor: ItineraryDraftExtracting {
    var endpoint: URL
    var session: URLSession = .shared

    func extract(_ text: String, scope: ItineraryInputScope, trip: Trip) async throws -> ProposedItineraryDraft {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let body = ExtractRequest(
            text: String(text.prefix(4000)),
            scope: scopeLabel(scope),
            tripName: trip.name.value,
            knownLegs: trip.legs.map { "\($0.origin.value ?? "")→\($0.destination.value ?? "")" }
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EngineError.invalidAnswer("Couldn’t understand that trip yet. Try adding it manually.")
        }
        let draft = try JSONDecoder().decode(ProposedItineraryDraft.self, from: data)
        return ItineraryDraftValidator.validated(draft, source: text)
    }

    private func scopeLabel(_ scope: ItineraryInputScope) -> String {
        switch scope {
        case .trip: "trip"
        case .leg: "leg"
        case .stay: "stay"
        case .activity: "activity"
        }
    }
}

nonisolated struct ExtractRequest: Codable, Sendable {
    var text: String
    var scope: String
    var tripName: String?
    var knownLegs: [String]
}

nonisolated enum ItineraryDraftValidator {
    static func validated(_ draft: ProposedItineraryDraft, source: String) -> ProposedItineraryDraft {
        var items: [ProposedItineraryItem] = []
        var unresolved = draft.unresolved
        for item in draft.items {
            let quote = item.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines)
            if quote.isEmpty || source.range(of: quote, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                unresolved.append("Dropped a suggestion that didn’t quote the original text.")
                continue
            }
            items.append(item)
        }
        return ProposedItineraryDraft(
            tripName: draft.tripName,
            startDate: draft.startDate,
            endDate: draft.endDate,
            items: items,
            unresolved: unresolved
        )
    }
}

nonisolated enum ItineraryDraftMutations {
    static func mutations(from draft: ProposedItineraryDraft, trip: Trip, now: Date) throws -> [TripMutation] {
        var mutations: [TripMutation] = []
        var knownLegs = trip.legs.map { ($0.id, $0.origin.value ?? "", $0.destination.value ?? "") }
        if let name = draft.tripName, !name.isEmpty {
            mutations.append(.setTripName(name))
        }
        if let start = draft.startDate.flatMap(parseDate) {
            mutations.append(.setTripStartDate(start))
        }
        if let end = draft.endDate.flatMap(parseDate) {
            mutations.append(.setTripEndDate(end))
        }
        for item in draft.items {
            switch item.kind {
            case .leg:
                let origin = item.origin ?? ""
                let destination = item.destination ?? ""
                guard !origin.isEmpty, !destination.isEmpty else {
                    continue
                }
                if let existing = knownLegs.first(where: {
                    $0.1.localizedCaseInsensitiveCompare(origin) == .orderedSame
                        && $0.2.localizedCaseInsensitiveCompare(destination) == .orderedSame
                }) {
                    if let date = item.date.flatMap(parseDate) {
                        let zone = TimeZone.current.identifier
                        mutations.append(.setLegScheduledAt(existing.0, try ScheduledMoment(date: date, timeZoneIdentifier: zone)))
                    }
                } else {
                    let moment = try item.date.flatMap(parseDate).map {
                        try ScheduledMoment(date: $0, timeZoneIdentifier: TimeZone.current.identifier)
                    }
                    let leg = try ItineraryItemFactory.makeLeg(
                        origin: origin,
                        destination: destination,
                        scheduledAt: moment,
                        at: now
                    )
                    knownLegs.append((leg.id, origin, destination))
                    mutations.append(.addLeg(leg, atTimelineIndex: nil))
                }
            case .stay:
                guard let place = item.place, !place.isEmpty else { continue }
                let checkIn = try item.checkIn.flatMap(parseDate).map {
                    try ScheduledMoment(date: $0, timeZoneIdentifier: TimeZone.current.identifier)
                }
                let stay = try ItineraryItemFactory.makeStay(place: place, checkIn: checkIn, at: now)
                mutations.append(.addStay(stay, atTimelineIndex: nil))
            case .activity:
                guard let title = item.title, !title.isEmpty else { continue }
                let moment = try item.date.flatMap(parseDate).map {
                    try ScheduledMoment(date: $0, timeZoneIdentifier: TimeZone.current.identifier)
                }
                let activity = try ItineraryItemFactory.makeActivity(
                    title: title,
                    place: item.place ?? "",
                    scheduledAt: moment,
                    at: now
                )
                mutations.append(.addActivity(activity, atTimelineIndex: nil))
            case .tripNote, .baggageHint:
                continue
            }
        }
        return mutations
    }

    private static func parseDate(_ raw: String) -> LocalDate? {
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return try? LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }
}
