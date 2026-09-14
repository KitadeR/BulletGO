import Foundation

nonisolated enum TripMutationApplier {
    static func apply(_ mutations: [TripMutation], to trip: Trip, at now: Date) throws -> Trip {
        try TripMutationTransaction.apply(mutations, to: trip, at: now).trip
    }

    static func apply(
        _ mutation: TripMutation,
        to trip: Trip,
        at now: Date,
        validate: Bool = true
    ) throws -> Trip {
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
            updated.startDate = try confirmedDate(updated.startDate, date, at: now)
        case .setTripEndDate(let date):
            updated.endDate = try confirmedDate(updated.endDate, date, at: now)
        case .setTripDateRange(let start, let end, let handling):
            updated.startDate = try confirmedDate(updated.startDate, start, at: now)
            updated.endDate = try confirmedDate(updated.endDate, end, at: now)
            let outOfRange = TripDateRangeImpact.outOfRangeItems(in: updated, start: start, end: end)
            if !outOfRange.isEmpty {
                switch handling {
                case .rejectOutOfRange:
                    throw TripValidationError.itemsOutsideDateRange(outOfRange.items)
                case .moveOutOfRangeToUnscheduledPreservingTiming:
                    for item in outOfRange.items {
                        try updated.moveItem(item, to: nil, at: now)
                    }
                }
            }
        case .addLeg(let leg, let index):
            guard !updated.legs.contains(where: { $0.id == leg.id }) else {
                throw TripValidationError.duplicateLegIDs
            }
            updated.legs.append(leg)
            try updated.insertTimelineItem(.leg(leg.id), at: index)
            updated.focusNewLegIfNeeded(leg.id)
            updated.pruneConnectorEstimates()
        case .updateLegOrigin(let legID, let place):
            try updated.updateLeg(id: legID) { leg in
                leg.origin = try confirmedString(leg.origin, place.name, at: now)
                leg.originPlace = place
            }
            updated.invalidateConnectorEstimates(touching: .leg(legID))
        case .updateLegDestination(let legID, let place):
            try updated.updateLeg(id: legID) { leg in
                leg.destination = try confirmedString(leg.destination, place.name, at: now)
                leg.destinationPlace = place
            }
            updated.invalidateConnectorEstimates(touching: .leg(legID))
        case .unscheduleLeg(let legID):
            try updated.updateLeg(id: legID) { leg in
                leg.scheduledAt = try stripDate(from: leg.scheduledAt, at: now)
                leg.arrivesAt = try stripDate(from: leg.arrivesAt, at: now)
            }
            updated.invalidateConnectorEstimates(touching: .leg(legID))
        case .removeLeg(let legID):
            _ = try updated.leg(id: legID)
            TripScopedDataPurger.purge(scope: .leg(legID), from: &updated)
            updated.legs.removeAll { $0.id == legID }
            updated.removeTimelineItem(matching: .leg(legID))
            updated.retargetFocusAfterRemovingLeg(legID)
            updated.pruneConnectorEstimates()
        case .addStay(let stay, let index):
            guard !updated.stays.contains(where: { $0.id == stay.id }) else {
                throw TripValidationError.duplicateStayIDs
            }
            updated.stays.append(stay)
            try updated.insertTimelineItem(.stay(stay.id), at: index)
            updated.pruneConnectorEstimates()
        case .updateStayPlace(let stayID, let place):
            try updated.updateStay(id: stayID) { stay in
                stay.place = try confirmedString(stay.place, place.name, at: now)
                stay.placeReference = place
            }
            updated.invalidateConnectorEstimates(touching: .stay(stayID))
        case .updateStayCheckIn(let stayID, let moment):
            try updated.updateStay(id: stayID) { stay in
                stay.checkIn = try confirmedMoment(stay.checkIn, moment, at: now)
            }
        case .updateStayCheckOut(let stayID, let moment):
            try updated.updateStay(id: stayID) { stay in
                stay.checkOut = try confirmedMoment(stay.checkOut, moment, at: now)
            }
        case .unscheduleStay(let stayID):
            try updated.updateStay(id: stayID) { stay in
                stay.checkIn = try stripDate(from: stay.checkIn, at: now)
                stay.checkOut = try stripDate(from: stay.checkOut, at: now)
            }
            updated.invalidateConnectorEstimates(touching: .stay(stayID))
        case .removeStay(let stayID):
            _ = try updated.stay(id: stayID)
            TripScopedDataPurger.purge(scope: .stay(stayID), from: &updated)
            updated.stays.removeAll { $0.id == stayID }
            updated.removeTimelineItem(matching: .stay(stayID))
            if case .stay(let id) = updated.currentContext.focus, id == stayID {
                updated.currentContext.focus = .none
            }
            updated.pruneConnectorEstimates()
        case .addActivity(let activity, let index):
            guard !updated.activities.contains(where: { $0.id == activity.id }) else {
                throw TripValidationError.duplicateActivityIDs
            }
            updated.activities.append(activity)
            try updated.insertTimelineItem(.activity(activity.id), at: index)
            updated.pruneConnectorEstimates()
        case .updateActivityTitle(let activityID, let title):
            try updated.updateActivity(id: activityID) { activity in
                activity.title = try confirmedString(activity.title, title, at: now)
            }
        case .updateActivityPlace(let activityID, let place):
            try updated.updateActivity(id: activityID) { activity in
                activity.place = try confirmedString(activity.place, place.name, at: now)
                activity.placeReference = place
            }
            updated.invalidateConnectorEstimates(touching: .activity(activityID))
        case .updateActivityScheduledAt(let activityID, let moment):
            try updated.updateActivity(id: activityID) { activity in
                activity.scheduledAt = try confirmedMoment(activity.scheduledAt, moment, at: now)
            }
        case .unscheduleActivity(let activityID):
            try updated.updateActivity(id: activityID) { activity in
                activity.scheduledAt = try stripDate(from: activity.scheduledAt, at: now)
                activity.endsAt = try stripDate(from: activity.endsAt, at: now)
            }
            updated.invalidateConnectorEstimates(touching: .activity(activityID))
        case .removeActivity(let activityID):
            _ = try updated.activity(id: activityID)
            TripScopedDataPurger.purge(scope: .activity(activityID), from: &updated)
            updated.activities.removeAll { $0.id == activityID }
            updated.removeTimelineItem(matching: .activity(activityID))
            if case .activity(let id) = updated.currentContext.focus, id == activityID {
                updated.currentContext.focus = .none
            }
            updated.pruneConnectorEstimates()
        case .moveTimelineItem(let from, let to):
            let item = try moveTimeline(&updated, from: from, to: to)
            updated.invalidateConnectorEstimates(touching: item)
            updated.pruneConnectorEstimates()
        case .moveTimelineItemID(let item, let toIndex):
            guard let from = updated.timeline.firstIndex(of: item) else {
                throw EngineError.invalidTimelineIndex
            }
            _ = try moveTimeline(&updated, from: from, to: toIndex)
            updated.invalidateConnectorEstimates(touching: item)
            updated.pruneConnectorEstimates()
        case .setLegScheduledAt(let legID, let moment):
            try updated.updateLeg(id: legID) { leg in
                leg.scheduledAt = try confirmedMoment(leg.scheduledAt, moment, at: now)
            }
        case .setTransportMode(let legID, let mode):
            try updated.updateLeg(id: legID) { leg in
                leg.transportMode = try confirmedValue(leg.transportMode, mode, at: now)
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
                leg.reservation.service = try confirmedValue(leg.reservation.service, service, at: now)
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
                bag.dimensions = try confirmedValue(bag.dimensions, dimensions, at: now)
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
        case .updateLegArrivesAt(let legID, let moment):
            try updated.updateLeg(id: legID) { leg in
                leg.arrivesAt = try confirmedMoment(leg.arrivesAt, moment, at: now)
            }
        case .updateActivityEndsAt(let activityID, let moment):
            try updated.updateActivity(id: activityID) { activity in
                activity.endsAt = try optionalMoment(activity.endsAt, moment, at: now)
            }
        case .replaceLegSchedule(let legID, let departure, let arrival):
            try updated.updateLeg(id: legID) { leg in
                leg.scheduledAt = try optionalMoment(leg.scheduledAt, departure, at: now)
                leg.arrivesAt = try optionalMoment(leg.arrivesAt, arrival, at: now)
            }
        case .replaceStaySchedule(let stayID, let checkIn, let checkOut):
            try updated.updateStay(id: stayID) { stay in
                stay.checkIn = try optionalMoment(stay.checkIn, checkIn, at: now)
                stay.checkOut = try optionalMoment(stay.checkOut, checkOut, at: now)
            }
        case .replaceActivitySchedule(let activityID, let start, let end):
            try updated.updateActivity(id: activityID) { activity in
                activity.scheduledAt = try optionalMoment(activity.scheduledAt, start, at: now)
                activity.endsAt = try optionalMoment(activity.endsAt, end, at: now)
            }
        case .moveItemToDate(let item, let date):
            try updated.moveItem(item, to: date, at: now)
            updated.invalidateConnectorEstimates(touching: item)
            updated.pruneConnectorEstimates()
        case .updateReservationDetails(let scope, let details):
            try updated.replaceReservation(in: scope, details: details, at: now)
        case .updateScopedReservationStatus(let scope, let status, let slotStatus):
            try updated.replaceReservation(in: scope, status: (status, slotStatus), at: now)
        case .upsertNote(let note):
            if let index = updated.notes.firstIndex(where: { $0.id == note.id }) {
                updated.notes[index] = note
            } else {
                updated.notes.append(note)
            }
        case .removeNote(let id):
            updated.notes.removeAll { $0.id == id }
        case .addAttachment(let record):
            if !updated.attachments.contains(where: { $0.id == record.id }) {
                updated.attachments.append(record)
            }
        case .renameAttachment(let id, let name):
            if let index = updated.attachments.firstIndex(where: { $0.id == id }) {
                updated.attachments[index].fileName = name
            }
        case .removeAttachment(let id):
            updated.attachments.removeAll { $0.id == id }
        case .addSavedPlace(let place):
            if !updated.savedPlaces.contains(where: { $0.id == place.id }) {
                updated.savedPlaces.append(place)
            }
        case .removeSavedPlace(let id):
            updated.savedPlaces.removeAll { $0.id == id }
        case .cacheConnectorEstimate(let estimate):
            updated.connectorEstimates.removeAll {
                $0.fromItem == estimate.fromItem && $0.toItem == estimate.toItem
            }
            updated.connectorEstimates.append(estimate)
        case .setDaySubtitle(let date, let text):
            updated.setDaySubtitle(text, on: date)
        case .restoreItineraryItem(let bundle):
            try TripScopedDataPurger.restore(bundle, into: &updated)
            updated.pruneConnectorEstimates()
        }

        if mutation.recordsChangeEvent {
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
        }
        if validate {
            try updated.validate()
        }
        return updated
    }

    @discardableResult
    private static func moveTimeline(_ trip: inout Trip, from: Int, to: Int) throws -> TripTimelineItem {
        guard trip.timeline.indices.contains(from), (0...trip.timeline.count).contains(to) else {
            throw EngineError.invalidTimelineIndex
        }
        let item = trip.timeline.remove(at: from)
        let destination = to > from ? to - 1 : to
        guard (0...trip.timeline.count).contains(destination) else {
            throw EngineError.invalidTimelineIndex
        }
        trip.timeline.insert(item, at: destination)
        return item
    }

    private static func confirmedDate(_ slot: Slot<LocalDate>, _ date: LocalDate, at now: Date) throws -> Slot<LocalDate> {
        try slot.updating(value: date, status: .confirmed, source: .userStated, confidence: .high, at: now)
    }

    private static func confirmedString(_ slot: Slot<String>, _ value: String, at now: Date) throws -> Slot<String> {
        try slot.updating(value: value, status: .confirmed, source: .userStated, confidence: .high, at: now)
    }

    private static func confirmedMoment(_ slot: Slot<ScheduledMoment>, _ moment: ScheduledMoment, at now: Date) throws -> Slot<ScheduledMoment> {
        try slot.updating(value: moment, status: .confirmed, source: .userStated, confidence: .high, at: now)
    }

    private static func confirmedValue<Value: Hashable & Codable & Sendable>(
        _ slot: Slot<Value>,
        _ value: Value,
        at now: Date
    ) throws -> Slot<Value> {
        try slot.updating(value: value, status: .confirmed, source: .userStated, confidence: .high, at: now)
    }

    private static func optionalMoment(
        _ slot: Slot<ScheduledMoment>,
        _ moment: ScheduledMoment?,
        at now: Date
    ) throws -> Slot<ScheduledMoment> {
        if let moment {
            return try confirmedMoment(slot, moment, at: now)
        }
        return try slot.updating(
            value: nil,
            status: .unknown,
            source: .userStated,
            confidence: nil,
            at: now
        )
    }

    static func stripDate(from slot: Slot<ScheduledMoment>, at now: Date) throws -> Slot<ScheduledMoment> {
        guard slot.status == .confirmed, let value = slot.value else {
            return slot
        }
        if let remaining = value.clearingDatePreservingTiming() {
            return try confirmedMoment(slot, remaining, at: now)
        }
        return try slot.updating(
            value: nil,
            status: .unknown,
            source: .userStated,
            confidence: nil,
            at: now
        )
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
        case .setTripName, .setTripStartDate, .setTripEndDate, .setTripDateRange, .moveTimelineItem, .moveTimelineItemID:
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
             .setSeatPreference(let legID, _),
             .updateLegArrivesAt(let legID, _),
             .replaceLegSchedule(let legID, _, _):
            .leg(legID)
        case .addStay(let stay, _):
            .stay(stay.id)
        case .updateStayPlace(let stayID, _),
             .updateStayCheckIn(let stayID, _),
             .updateStayCheckOut(let stayID, _),
             .unscheduleStay(let stayID),
             .removeStay(let stayID),
             .replaceStaySchedule(let stayID, _, _):
            .stay(stayID)
        case .addActivity(let activity, _):
            .activity(activity.id)
        case .updateActivityTitle(let activityID, _),
             .updateActivityPlace(let activityID, _),
             .updateActivityScheduledAt(let activityID, _),
             .unscheduleActivity(let activityID),
             .removeActivity(let activityID),
             .updateActivityEndsAt(let activityID, _),
             .replaceActivitySchedule(let activityID, _, _):
            .activity(activityID)
        case .setBagDimensions:
            .trip
        case .moveItemToDate(let item, _):
            switch item {
            case .leg(let id): .leg(id)
            case .stay(let id): .stay(id)
            case .activity(let id): .activity(id)
            }
        case .updateReservationDetails(let scope, _), .updateScopedReservationStatus(let scope, _, _):
            scope
        case .upsertNote, .removeNote, .addAttachment, .renameAttachment, .removeAttachment,
             .addSavedPlace, .removeSavedPlace, .cacheConnectorEstimate, .setDaySubtitle, .restoreItineraryItem:
            .trip
        }
    }
}
