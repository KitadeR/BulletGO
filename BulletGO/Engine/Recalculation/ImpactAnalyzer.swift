import Foundation

nonisolated enum ImpactAnalyzer {
    static func analyze(_ mutation: TripMutation) -> (kind: ChangeEventKind, assessment: ImpactAssessment) {
        switch mutation {
        case .setTripName:
            itinerary([], [.trip(.timeline)])
        case .setTripStartDate, .setTripEndDate, .setTripDateRange:
            (
                .itineraryChanged,
                ImpactAssessment(level: .medium, targetLegs: [], changedPaths: [.trip(.startDate), .trip(.endDate)])
            )
        case .addLeg(let leg, _):
            itinerary([leg.id], [.trip(.timeline)])
        case .updateLegOrigin(let legID, _), .updateLegDestination(let legID, _):
            itinerary([legID], [.leg(legID, .origin), .leg(legID, .destination)])
        case .unscheduleLeg(let legID):
            itinerary([legID], [.leg(legID, .scheduledAt)])
        case .removeLeg(let legID):
            itinerary([legID], [.trip(.timeline)])
        case .addStay, .updateStayPlace, .updateStayCheckIn, .updateStayCheckOut, .unscheduleStay, .removeStay,
             .replaceStaySchedule:
            itinerary([], [.trip(.timeline)])
        case .addActivity, .updateActivityTitle, .updateActivityPlace, .updateActivityScheduledAt,
             .unscheduleActivity, .removeActivity, .updateActivityEndsAt, .replaceActivitySchedule:
            itinerary([], [.trip(.timeline)])
        case .moveTimelineItem, .moveTimelineItemID:
            itinerary([], [.trip(.timeline)])
        case .setLegScheduledAt(let legID, _):
            (
                .dateChanged,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .scheduledAt)]
                )
            )
        case .setTransportMode(let legID, _):
            (
                .transportChanged,
                ImpactAssessment(
                    level: .high,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .transportMode)]
                )
            )
        case .setReservationStatus(let legID, _, _), .setBookingService(let legID, _):
            (
                .reservationUpdated,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .reservation)]
                )
            )
        case .setBaggagePresence(let legID, _, _):
            (
                .other,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .baggagePresence)]
                )
            )
        case .addBag(let legID, _):
            (
                .luggageAdded,
                ImpactAssessment(
                    level: .medium,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .bagIDs)]
                )
            )
        case .setBagDimensions(let bagID, _):
            (
                .other,
                ImpactAssessment(
                    level: .low,
                    targetLegs: [],
                    changedPaths: [.bag(bagID, .dimensions)]
                )
            )
        case .setSeatPreference(let legID, _):
            (
                .other,
                ImpactAssessment(
                    level: .low,
                    targetLegs: [legID],
                    changedPaths: [.leg(legID, .seatPreference)]
                )
            )
        case .updateLegArrivesAt(let legID, _), .replaceLegSchedule(let legID, _, _):
            itinerary([legID], [.leg(legID, .scheduledAt)])
        case .moveItemToDate(let item, _):
            switch item {
            case .leg(let id):
                itinerary([id], [.leg(id, .scheduledAt)])
            case .stay, .activity:
                itinerary([], [.trip(.timeline)])
            }
        case .updateReservationDetails(let scope, _), .updateScopedReservationStatus(let scope, _, _):
            (
                .reservationUpdated,
                ImpactAssessment(level: .medium, targetLegs: reservationLegs(scope), changedPaths: [.trip(.timeline)])
            )
        case .upsertNote, .removeNote, .addAttachment, .renameAttachment, .removeAttachment,
             .addSavedPlace, .removeSavedPlace, .setDaySubtitle, .restoreItineraryItem:
            (
                .other,
                ImpactAssessment(level: .low, targetLegs: [], changedPaths: [.trip(.timeline)])
            )
        case .cacheConnectorEstimate:
            (
                .other,
                ImpactAssessment(level: .low, targetLegs: [], changedPaths: [])
            )
        }
    }

    private static func itinerary(_ legs: [LegID], _ paths: [DomainPath]) -> (ChangeEventKind, ImpactAssessment) {
        (
            .itineraryChanged,
            ImpactAssessment(level: .medium, targetLegs: legs, changedPaths: paths)
        )
    }

    private static func reservationLegs(_ scope: DomainScope) -> [LegID] {
        if case .leg(let id) = scope {
            return [id]
        }
        return []
    }
}

nonisolated struct ImpactAssessment: Hashable, Sendable {
    var level: ChangeImpactLevel
    var targetLegs: [LegID]
    var changedPaths: [DomainPath]
}

extension ImpactAssessment {
    func resolvedLegIDs(in trip: Trip, bagIDs: [BagID] = []) -> [LegID] {
        var ids = Set(targetLegs)
        if changedPaths.contains(where: {
            if case .trip(.startDate) = $0 { return true }
            if case .trip(.endDate) = $0 { return true }
            return false
        }) {
            ids.formUnion(trip.legs.map(\.id))
        }
        let bags = Set(bagIDs + changedPaths.compactMap { path -> BagID? in
            if case .bag(let id, _) = path { return id }
            return nil
        })
        if !bags.isEmpty {
            for leg in trip.legs where leg.bagIDs.contains(where: bags.contains) {
                ids.insert(leg.id)
            }
        }
        return Array(ids)
    }
}
