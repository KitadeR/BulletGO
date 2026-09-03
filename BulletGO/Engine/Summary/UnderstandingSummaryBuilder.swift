import Foundation

nonisolated enum UnderstandingSummaryBuilder {
    static func build(
        before: Trip,
        after: Trip,
        changedPaths: [DomainPath],
        catalog: QuestionCatalog,
        activeDecisionPoints: Set<DecisionPointID>
    ) -> UnderstandingSummary {
        var confirmed: [UnderstandingSummaryItem] = []
        var deferred: [UnderstandingSummaryItem] = []

        for path in unique(changedPaths) {
            guard let classified = classifyChangedPath(path, before: before, after: after) else {
                continue
            }
            switch classified.bucket {
            case .confirmed:
                confirmed.append(classified.item)
            case .deferred:
                deferred.append(classified.item)
            }
        }

        let unconfirmed = QuestionEngine.applicableUnsatisfiedQuestions(
            in: after,
            catalog: catalog,
            activeDecisionPoints: activeDecisionPoints
        ).compactMap { question in
            unconfirmedItem(for: question, trip: after)
        }

        return UnderstandingSummary(
            confirmed: confirmed,
            deferred: deferred,
            unconfirmed: unconfirmed
        )
    }

    private enum Bucket {
        case confirmed
        case deferred
    }

    private static func classifyChangedPath(
        _ path: DomainPath,
        before: Trip,
        after: Trip
    ) -> (item: UnderstandingSummaryItem, bucket: Bucket)? {
        switch path {
        case .leg(let id, .scheduledAt):
            classify(slot: after.legs.first { $0.id == id }?.scheduledAt) { value in
                item(
                    contentKey: "leg.scheduledAt",
                    scope: .leg(id),
                    path: path,
                    value: .scheduledMoment(value),
                    relatedQuestionID: .legDate
                )
            }
        case .leg(let id, .transportMode):
            classify(slot: after.legs.first { $0.id == id }?.transportMode) { value in
                item(
                    contentKey: "leg.transportMode",
                    scope: .leg(id),
                    path: path,
                    value: .transportMode(value),
                    relatedQuestionID: .transport
                )
            }
        case .leg(let id, .baggagePresence):
            classify(slot: after.legs.first { $0.id == id }?.baggagePresence) { value in
                item(
                    contentKey: "leg.baggagePresence",
                    scope: .leg(id),
                    path: path,
                    value: .baggagePresence(value),
                    relatedQuestionID: .luggagePresence
                )
            }
        case .leg(let id, .seatPreference):
            classify(slot: after.legs.first { $0.id == id }?.seatPreference) { value in
                item(
                    contentKey: "leg.seatPreference",
                    scope: .leg(id),
                    path: path,
                    value: .seatPreference(value),
                    relatedDecisionPointID: .seatSelection
                )
            }
        case .leg(let id, .reservation):
            reservationItem(id: id, before: before, after: after, path: path)
        case .bag(let id, .dimensions):
            classify(slot: after.baggageInventory.first { $0.id == id }?.dimensions) { value in
                item(
                    contentKey: "bag.dimensions",
                    scope: .trip,
                    path: path,
                    value: .baggageDimensions(value),
                    relatedQuestionID: .baggageDimensions,
                    relatedDecisionPointID: .baggagePolicyEvaluation
                )
            }
        default:
            nil
        }
    }

    private static func reservationItem(
        id: LegID,
        before: Trip,
        after: Trip,
        path: DomainPath
    ) -> (item: UnderstandingSummaryItem, bucket: Bucket)? {
        let beforeLeg = before.legs.first { $0.id == id }
        let afterLeg = after.legs.first { $0.id == id }
        if afterLeg?.reservation.status != beforeLeg?.reservation.status {
            return classify(slot: afterLeg?.reservation.status) { value in
                item(
                    contentKey: "leg.reservationStatus",
                    scope: .leg(id),
                    path: path,
                    value: .reservationStatus(value),
                    relatedQuestionID: .ticketStatus
                )
            }
        }
        if afterLeg?.reservation.service != beforeLeg?.reservation.service {
            return classify(slot: afterLeg?.reservation.service) { value in
                item(
                    contentKey: "leg.reservationService",
                    scope: .leg(id),
                    path: path,
                    value: .bookingService(value),
                    relatedQuestionID: .selectService
                )
            }
        }
        return nil
    }

    private static func classify<Value: Hashable & Codable & Sendable>(
        slot: Slot<Value>?,
        makeItem: (Value) -> UnderstandingSummaryItem
    ) -> (item: UnderstandingSummaryItem, bucket: Bucket)? {
        guard let slot, slot.status == .confirmed, let value = slot.value else {
            return nil
        }
        let bucket: Bucket = slot.isDeferredPresentation ? .deferred : .confirmed
        return (makeItem(value), bucket)
    }

    private static func unconfirmedItem(for question: QuestionSpec, trip: Trip) -> UnderstandingSummaryItem? {
        guard let leg = try? trip.focusLeg() else {
            return nil
        }
        let path: DomainPath
        var relatedDecisionPoint: DecisionPointID?
        switch question.target {
        case .legScheduledAt:
            path = .leg(leg.id, .scheduledAt)
        case .legTransportMode:
            path = .leg(leg.id, .transportMode)
        case .legReservationStatus:
            path = .leg(leg.id, .reservation)
        case .legReservationService:
            path = .leg(leg.id, .reservation)
        case .legBaggagePresence:
            path = .leg(leg.id, .baggagePresence)
        case .bagDimensions:
            guard let bagID = leg.bagIDs.first else {
                return nil
            }
            path = .bag(bagID, .dimensions)
            relatedDecisionPoint = .baggagePolicyEvaluation
        }
        return item(
            contentKey: question.id.rawValue,
            scope: .leg(leg.id),
            path: path,
            relatedQuestionID: question.id,
            relatedDecisionPointID: relatedDecisionPoint
        )
    }

    private static func item(
        contentKey: String,
        scope: DomainScope,
        path: DomainPath,
        value: UnderstandingSummaryValue? = nil,
        relatedQuestionID: QuestionID? = nil,
        relatedDecisionPointID: DecisionPointID? = nil
    ) -> UnderstandingSummaryItem {
        UnderstandingSummaryItem(
            contentKey: contentKey,
            scope: scope,
            path: path,
            value: value,
            relatedQuestionID: relatedQuestionID,
            relatedDecisionPointID: relatedDecisionPointID
        )
    }

    private static func unique(_ paths: [DomainPath]) -> [DomainPath] {
        var seen: [DomainPath] = []
        for path in paths where !seen.contains(path) {
            seen.append(path)
        }
        return seen
    }
}
