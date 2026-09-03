import Foundation

nonisolated enum TripMutationApplier {
    static func apply(_ mutation: TripMutation, to trip: Trip, at now: Date) throws -> Trip {
        var updated = trip
        let impact = ImpactAnalyzer.analyze(mutation)
        switch mutation {
        case .setLegScheduledAt(let legID, let moment):
            try updated.updateLeg(id: legID) { leg in
                leg.scheduledAt = try leg.scheduledAt.updating(
                    value: moment,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .setTransportMode(let legID, let mode):
            try updated.updateLeg(id: legID) { leg in
                leg.transportMode = try leg.transportMode.updating(
                    value: mode,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .setReservationStatus(let legID, let status, let slotStatus):
            try updated.updateLeg(id: legID) { leg in
                leg.reservation.status = try updatedSlot(
                    leg.reservation.status,
                    value: status,
                    status: slotStatus,
                    at: now
                )
            }
        case .setBookingService(let legID, let service):
            try updated.updateLeg(id: legID) { leg in
                leg.reservation.service = try leg.reservation.service.updating(
                    value: service,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .setBaggagePresence(let legID, let presence, let slotStatus):
            try updated.updateLeg(id: legID) { leg in
                leg.baggagePresence = try updatedSlot(
                    leg.baggagePresence,
                    value: presence,
                    status: slotStatus,
                    at: now
                )
            }
        case .addBag(let legID, let bagID):
            try updated.updateLeg(id: legID) { leg in
                if !leg.bagIDs.contains(bagID) {
                    leg.bagIDs.append(bagID)
                }
            }
            if !updated.baggageInventory.contains(where: { $0.id == bagID }) {
                updated.baggageInventory.append(
                    Bag(
                        id: bagID,
                        kind: try Slot.unknown(updatedAt: now),
                        userDescription: try Slot.unknown(updatedAt: now),
                        perceivedSize: try Slot.unknown(updatedAt: now),
                        dimensions: try Slot.unknown(
                            collectionTiming: .justInTime(.baggagePolicyEvaluation),
                            updatedAt: now
                        ),
                        weightKilograms: try Slot.unknown(updatedAt: now),
                        createdAt: now
                    )
                )
            }
        case .setBagDimensions(let bagID, let dimensions):
            try updated.updateBag(id: bagID) { bag in
                bag.dimensions = try bag.dimensions.updating(
                    value: dimensions,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        }

        updated.changeEvents.append(
            TripChangeEvent(
                id: ChangeEventID(),
                kind: impact.kind,
                target: mutationTarget(mutation),
                changedPaths: impact.assessment.changedPaths,
                affectedFrom: nil,
                potentialScope: .specificLegs(impact.assessment.targetLegs),
                impactLevel: impact.assessment.level,
                createdAt: now
            )
        )
        updated.updatedAt = now
        try updated.validate()
        return updated
    }

    private static func updatedSlot<Value: Hashable & Codable & Sendable>(
        _ slot: Slot<Value>,
        value: Value?,
        status: SlotStatus,
        at now: Date
    ) throws -> Slot<Value> {
        switch status {
        case .confirmed:
            guard let value else {
                throw EngineError.invalidAnswer("confirmed slot requires a value")
            }
            return try slot.updating(
                value: value,
                status: .confirmed,
                source: .userStated,
                confidence: .high,
                at: now
            )
        case .skipped:
            return try slot.updating(
                value: nil,
                status: .skipped,
                source: .userStated,
                confidence: nil,
                at: now
            )
        case .negative:
            return try slot.updating(
                value: value,
                status: .negative,
                source: .userStated,
                confidence: .high,
                at: now
            )
        case .unknown, .inferred, .notApplicable:
            throw EngineError.invalidAnswer("unsupported mutation slot status")
        }
    }

    private static func mutationTarget(_ mutation: TripMutation) -> DomainScope {
        switch mutation {
        case .setLegScheduledAt(let legID, _),
             .setTransportMode(let legID, _),
             .setReservationStatus(let legID, _, _),
             .setBookingService(let legID, _),
             .setBaggagePresence(let legID, _, _),
             .addBag(let legID, _):
            .leg(legID)
        case .setBagDimensions:
            .trip
        }
    }
}
