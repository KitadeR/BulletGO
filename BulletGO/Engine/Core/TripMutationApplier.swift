import Foundation

nonisolated enum TripMutationApplier {
    static func apply(_ mutations: [TripMutation], to trip: Trip, at now: Date) throws -> Trip {
        var updated = trip
        for mutation in mutations {
            updated = try apply(mutation, to: updated, at: now)
        }
        return updated
    }

    static func apply(_ mutation: TripMutation, to trip: Trip, at now: Date) throws -> Trip {
        var updated = trip
        let impact = ImpactAnalyzer.analyze(mutation)
        switch mutation {
        case .setTripName(let name):
            updated.name = try updated.name.updating(
                value: name,
                status: .confirmed,
                source: .userStated,
                confidence: .high,
                at: now
            )
        case .setTripStartDate(let date):
            updated.startDate = try updated.startDate.updating(
                value: date,
                status: .confirmed,
                source: .userStated,
                confidence: .high,
                at: now
            )
        case .setTripEndDate(let date):
            updated.endDate = try updated.endDate.updating(
                value: date,
                status: .confirmed,
                source: .userStated,
                confidence: .high,
                at: now
            )
        case .addLeg(let leg, let index):
            guard !updated.legs.contains(where: { $0.id == leg.id }) else {
                throw TripValidationError.duplicateLegIDs
            }
            updated.legs.append(leg)
            try updated.insertTimelineItem(.leg(leg.id), at: index)
            updated.focusNewLegIfNeeded(leg.id)
        case .updateLegOrigin(let legID, let origin):
            try updated.updateLeg(id: legID) { leg in
                leg.origin = try leg.origin.updating(
                    value: origin,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .updateLegDestination(let legID, let destination):
            try updated.updateLeg(id: legID) { leg in
                leg.destination = try leg.destination.updating(
                    value: destination,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .unscheduleLeg(let legID):
            try updated.updateLeg(id: legID) { leg in
                leg.scheduledAt = try leg.scheduledAt.updating(
                    value: nil,
                    status: .unknown,
                    source: .userStated,
                    confidence: nil,
                    at: now
                )
            }
        case .removeLeg(let legID):
            _ = try updated.leg(id: legID)
            updated.legs.removeAll { $0.id == legID }
            updated.removeTimelineItem(matching: .leg(legID))
            updated.tasks.removeAll { task in
                if case .leg(let id) = task.scope { return id == legID }
                return false
            }
            updated.retargetFocusAfterRemovingLeg(legID)
        case .addStay(let stay, let index):
            guard !updated.stays.contains(where: { $0.id == stay.id }) else {
                throw TripValidationError.duplicateStayIDs
            }
            updated.stays.append(stay)
            try updated.insertTimelineItem(.stay(stay.id), at: index)
        case .updateStayPlace(let stayID, let place):
            try updated.updateStay(id: stayID) { stay in
                stay.place = try stay.place.updating(
                    value: place,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .updateStayCheckIn(let stayID, let moment):
            try updated.updateStay(id: stayID) { stay in
                stay.checkIn = try stay.checkIn.updating(
                    value: moment,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .updateStayCheckOut(let stayID, let moment):
            try updated.updateStay(id: stayID) { stay in
                stay.checkOut = try stay.checkOut.updating(
                    value: moment,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .unscheduleStay(let stayID):
            try updated.updateStay(id: stayID) { stay in
                stay.checkIn = try stay.checkIn.updating(
                    value: nil,
                    status: .unknown,
                    source: .userStated,
                    confidence: nil,
                    at: now
                )
                stay.checkOut = try stay.checkOut.updating(
                    value: nil,
                    status: .unknown,
                    source: .userStated,
                    confidence: nil,
                    at: now
                )
            }
        case .removeStay(let stayID):
            _ = try updated.stay(id: stayID)
            updated.stays.removeAll { $0.id == stayID }
            updated.removeTimelineItem(matching: .stay(stayID))
            if case .stay(let id) = updated.currentContext.focus, id == stayID {
                updated.currentContext.focus = .none
            }
        case .addActivity(let activity, let index):
            guard !updated.activities.contains(where: { $0.id == activity.id }) else {
                throw TripValidationError.duplicateActivityIDs
            }
            updated.activities.append(activity)
            try updated.insertTimelineItem(.activity(activity.id), at: index)
        case .updateActivityTitle(let activityID, let title):
            try updated.updateActivity(id: activityID) { activity in
                activity.title = try activity.title.updating(
                    value: title,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .updateActivityPlace(let activityID, let place):
            try updated.updateActivity(id: activityID) { activity in
                activity.place = try activity.place.updating(
                    value: place,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .updateActivityScheduledAt(let activityID, let moment):
            try updated.updateActivity(id: activityID) { activity in
                activity.scheduledAt = try activity.scheduledAt.updating(
                    value: moment,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    at: now
                )
            }
        case .unscheduleActivity(let activityID):
            try updated.updateActivity(id: activityID) { activity in
                activity.scheduledAt = try activity.scheduledAt.updating(
                    value: nil,
                    status: .unknown,
                    source: .userStated,
                    confidence: nil,
                    at: now
                )
            }
        case .removeActivity(let activityID):
            _ = try updated.activity(id: activityID)
            updated.activities.removeAll { $0.id == activityID }
            updated.removeTimelineItem(matching: .activity(activityID))
            if case .activity(let id) = updated.currentContext.focus, id == activityID {
                updated.currentContext.focus = .none
            }
        case .moveTimelineItem(let from, let to):
            guard updated.timeline.indices.contains(from), (0...updated.timeline.count).contains(to) else {
                throw EngineError.invalidTimelineIndex
            }
            let item = updated.timeline.remove(at: from)
            let destination = to > from ? to - 1 : to
            guard (0...updated.timeline.count).contains(destination) else {
                throw EngineError.invalidTimelineIndex
            }
            updated.timeline.insert(item, at: destination)
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
        case .setSeatPreference(let legID, let preference):
            try updated.updateLeg(id: legID) { leg in
                leg.seatPreference = try leg.seatPreference.updating(
                    value: preference,
                    status: .confirmed,
                    source: .userStated,
                    confidence: .high,
                    presentationTiming: .deferred(until: .seatSelection),
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
        case .setTripName, .setTripStartDate, .setTripEndDate, .moveTimelineItem:
            .trip
        case .addLeg(let leg, _):
            .leg(leg.id)
        case .updateLegOrigin(let legID, _),
             .updateLegDestination(let legID, _),
             .unscheduleLeg(let legID),
             .removeLeg(let legID),
             .setLegScheduledAt(let legID, _),
             .setTransportMode(let legID, _),
             .setReservationStatus(let legID, _, _),
             .setBookingService(let legID, _),
             .setBaggagePresence(let legID, _, _),
             .addBag(let legID, _),
             .setSeatPreference(let legID, _):
            .leg(legID)
        case .addStay(let stay, _):
            .stay(stay.id)
        case .updateStayPlace(let stayID, _),
             .updateStayCheckIn(let stayID, _),
             .updateStayCheckOut(let stayID, _),
             .unscheduleStay(let stayID),
             .removeStay(let stayID):
            .stay(stayID)
        case .addActivity(let activity, _):
            .activity(activity.id)
        case .updateActivityTitle(let activityID, _),
             .updateActivityPlace(let activityID, _),
             .updateActivityScheduledAt(let activityID, _),
             .unscheduleActivity(let activityID),
             .removeActivity(let activityID):
            .activity(activityID)
        case .setBagDimensions:
            .trip
        }
    }
}
