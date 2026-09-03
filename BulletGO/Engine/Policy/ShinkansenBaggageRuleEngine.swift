import Foundation

nonisolated enum ShinkansenBaggageRuleEngine {
    static func evaluate(_ trip: Trip, pack: BaggagePolicyPack, at now: Date) throws -> Trip {
        guard let focusID = trip.focusLegID else {
            return trip
        }
        var updated = trip
        let focus = try updated.leg(id: focusID)
        let nextEvaluations = evaluations(for: focus, trip: updated, pack: pack, at: now)
        try updated.updateLeg(id: focusID) { leg in
            leg.policyEvaluations = nextEvaluations
        }
        return updated
    }

    private static func evaluations(
        for leg: Leg,
        trip: Trip,
        pack: BaggagePolicyPack,
        at now: Date
    ) -> [PolicyEvaluation] {
        let existing = leg.policyEvaluations.filter { $0.policyID == pack.id }
        let others = leg.policyEvaluations.filter { $0.policyID != pack.id }
        let transportConfirmed = leg.transportMode.status == .confirmed
        let applies = transportConfirmed && pack.appliesToTransport.contains(leg.transportMode.value ?? .other)

        if transportConfirmed && !applies {
            let stale = existing.map { evaluation in
                var copy = evaluation
                copy.status = .stale
                copy.evaluatedAt = now
                return copy
            }
            return others + stale
        }

        let desired: [PolicyEvaluation]
        if !transportConfirmed {
            desired = [
                makeEvaluation(
                    matching: existing,
                    pack: pack,
                    scope: .leg(leg.id),
                    bagID: nil,
                    status: .needsMoreInformation,
                    missing: [.leg(leg.id, .transportMode)],
                    result: [:],
                    effectiveDate: effectiveDate(for: leg, trip: trip),
                    at: now
                ),
            ]
        } else if effectiveDate(for: leg, trip: trip) == nil {
            desired = [
                makeEvaluation(
                    matching: existing,
                    pack: pack,
                    scope: .leg(leg.id),
                    bagID: nil,
                    status: .needsMoreInformation,
                    missing: [.leg(leg.id, .scheduledAt)],
                    result: [:],
                    effectiveDate: nil,
                    at: now
                ),
            ]
        } else if !leg.baggagePresence.isSatisfiedForQuestioning {
            desired = [
                makeEvaluation(
                    matching: existing,
                    pack: pack,
                    scope: .leg(leg.id),
                    bagID: nil,
                    status: .needsMoreInformation,
                    missing: [.leg(leg.id, .baggagePresence)],
                    result: [:],
                    effectiveDate: effectiveDate(for: leg, trip: trip),
                    at: now
                ),
            ]
        } else if leg.baggagePresence.status == .skipped
            || (leg.baggagePresence.status == .confirmed && leg.baggagePresence.value == .no)
        {
            desired = [
                makeEvaluation(
                    matching: existing,
                    pack: pack,
                    scope: .leg(leg.id),
                    bagID: nil,
                    status: .evaluated,
                    missing: [],
                    result: [pack.resultKey: BaggagePolicyPack.ReservationRequirement.notRequired.rawValue],
                    effectiveDate: effectiveDate(for: leg, trip: trip),
                    at: now
                ),
            ]
        } else if leg.bagIDs.isEmpty {
            desired = [
                makeEvaluation(
                    matching: existing,
                    pack: pack,
                    scope: .leg(leg.id),
                    bagID: nil,
                    status: .needsMoreInformation,
                    missing: [.leg(leg.id, .bagIDs)],
                    result: [:],
                    effectiveDate: effectiveDate(for: leg, trip: trip),
                    at: now
                ),
            ]
        } else {
            desired = leg.bagIDs.map { bagID in
                evaluateBag(
                    bagID,
                    leg: leg,
                    trip: trip,
                    pack: pack,
                    existing: existing,
                    at: now
                )
            }
        }

        let desiredKeys = Set(desired.map(identityKey))
        let leftovers = existing
            .filter { !desiredKeys.contains(identityKey($0)) }
            .map { evaluation -> PolicyEvaluation in
                var copy = evaluation
                copy.status = .stale
                copy.evaluatedAt = now
                return copy
            }
        return others + desired + leftovers
    }

    private static func evaluateBag(
        _ bagID: BagID,
        leg: Leg,
        trip: Trip,
        pack: BaggagePolicyPack,
        existing: [PolicyEvaluation],
        at now: Date
    ) -> PolicyEvaluation {
        let date = effectiveDate(for: leg, trip: trip)
        guard let bag = trip.baggageInventory.first(where: { $0.id == bagID }),
              bag.dimensions.status == .confirmed,
              let dimensions = bag.dimensions.value
        else {
            return makeEvaluation(
                matching: existing,
                pack: pack,
                scope: .leg(leg.id),
                bagID: bagID,
                status: .needsMoreInformation,
                missing: [.bag(bagID, .dimensions)],
                result: [:],
                effectiveDate: date,
                at: now
            )
        }
        let requirement = pack.requirement(forTotalCM: dimensions.totalCM)
        return makeEvaluation(
            matching: existing,
            pack: pack,
            scope: .leg(leg.id),
            bagID: bagID,
            status: .evaluated,
            missing: [],
            result: [pack.resultKey: requirement.rawValue],
            effectiveDate: date,
            at: now
        )
    }

    private static func makeEvaluation(
        matching existing: [PolicyEvaluation],
        pack: BaggagePolicyPack,
        scope: DomainScope,
        bagID: BagID?,
        status: PolicyEvaluationStatus,
        missing: [DomainPath],
        result: [String: String],
        effectiveDate: LocalDate?,
        at now: Date
    ) -> PolicyEvaluation {
        let matched = existing.first { evaluation in
            evaluation.policyID == pack.id && evaluation.scope == scope && evaluation.bagID == bagID
        }
        return PolicyEvaluation(
            id: matched?.id ?? PolicyEvaluationID(),
            policyID: pack.id,
            policyVersion: pack.version,
            effectiveDate: effectiveDate,
            scope: scope,
            bagID: bagID,
            status: status,
            missingFieldPaths: missing,
            resultFields: result,
            evaluatedAt: now
        )
    }

    private static func identityKey(_ evaluation: PolicyEvaluation) -> String {
        "\(evaluation.policyID.rawValue)|\(String(describing: evaluation.scope))|\(evaluation.bagID?.rawValue.uuidString ?? "none")"
    }

    private static func effectiveDate(for leg: Leg, trip: Trip) -> LocalDate? {
        if leg.scheduledAt.status == .confirmed {
            return leg.scheduledAt.value?.date
        }
        if trip.startDate.status == .confirmed {
            return trip.startDate.value
        }
        return nil
    }
}
