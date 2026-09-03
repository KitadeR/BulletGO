import Foundation

nonisolated enum ActionPurpose {
    static let captureDimensions = "capture_dimensions"
    static let selectBookingMethod = "select_booking_method"
    static let reserveOversizedSeat = "reserve_oversized_seat"
    static let verifyReservationMeetsBaggage = "verify_reservation_meets_baggage"
}

nonisolated enum ActionResolver {
    static func resolve(trip: Trip, pack: BaggagePolicyPack) -> [ActionRequirement] {
        guard let leg = try? trip.focusLeg() else {
            return []
        }
        var actions: [ActionRequirement] = []
        if shouldSelectBookingMethod(leg) {
            actions.append(makeAction(ActionPurpose.selectBookingMethod, pack: pack))
        }
        for evaluation in leg.policyEvaluations where evaluation.policyID == pack.id && evaluation.status != .stale {
            if evaluation.status == .needsMoreInformation,
               evaluation.missingFieldPaths.contains(where: { path in
                   if case .bag(_, .dimensions) = path { return true }
                   return false
               })
            {
                actions.append(makeAction(ActionPurpose.captureDimensions, pack: pack))
            }
            if evaluation.status == .evaluated,
               evaluation.resultFields[pack.resultKey] == BaggagePolicyPack.ReservationRequirement.required.rawValue
            {
                if leg.reservation.status.value == .booked, leg.reservation.status.status == .confirmed {
                    actions.append(makeAction(ActionPurpose.verifyReservationMeetsBaggage, pack: pack))
                } else {
                    actions.append(makeAction(ActionPurpose.reserveOversizedSeat, pack: pack))
                }
            }
        }
        return uniqued(actions)
    }

    private static func shouldSelectBookingMethod(_ leg: Leg) -> Bool {
        leg.transportMode.status == .confirmed
            && leg.transportMode.value == .shinkansen
            && leg.reservation.status.status == .confirmed
            && leg.reservation.status.value == .notBooked
            && !leg.reservation.service.isSatisfiedForQuestioning
    }

    private static func makeAction(
        _ purposeKey: String,
        pack: BaggagePolicyPack
    ) -> ActionRequirement {
        let template = pack.actionTemplate(purposeKey: purposeKey)
        return ActionRequirement(
            id: ActionRequirementID(),
            purposeKey: purposeKey,
            importance: template?.importance ?? .mustDo,
            relatedPolicyID: pack.id,
            requiredStateSummary: template?.requiredStateSummary ?? purposeKey,
            completionCondition: template?.completionCondition ?? purposeKey
        )
    }

    private static func uniqued(_ actions: [ActionRequirement]) -> [ActionRequirement] {
        var seen = Set<String>()
        return actions.filter { seen.insert($0.purposeKey).inserted }
    }
}
