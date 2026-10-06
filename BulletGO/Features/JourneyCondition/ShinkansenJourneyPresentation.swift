import Foundation

/// Read-only presentation derived from itinerary and policy facts. Nothing here is persisted.
nonisolated struct ShinkansenJourneyPresentation: Equatable, Sendable {
    enum Focus: String, Sendable { case conditions, reservation, boarding, travelDay }
    enum Baggage: Equatable, Sendable {
        case unanswered, deferred, none, needsMeasurement, withinLimit, oversizedSeat, notAllowed
    }

    let focus: Focus
    let baggage: Baggage
    let booking: ReservationStatus?
    let route: String
    let date: String?
    let boarding: StatedBoardingMeans?
    let hasRecordedDetails: Bool
    let oversizedSeatReserved: Bool?

    static func make(trip: Trip, leg: Leg, pack: BaggagePolicyPack?) -> Self {
        let booking = leg.reservation.status.status == .confirmed ? leg.reservation.status.value : nil
        let baggage: Baggage
        switch (leg.baggagePresence.status, leg.baggagePresence.value) {
        case (.skipped, _): baggage = .deferred
        case (.confirmed, .no): baggage = .none
        case (.confirmed, .yes):
            let bags = leg.bagIDs.compactMap { id in trip.baggageInventory.first { $0.id == id } }
            if bags.isEmpty || bags.contains(where: { $0.dimensions.status != .confirmed || $0.dimensions.value == nil }) {
                baggage = .needsMeasurement
            } else if let pack {
                let requirements = bags.compactMap { $0.dimensions.value }.map { pack.requirement(forTotalCM: $0.totalCM) }
                if requirements.contains(.notAllowed) { baggage = .notAllowed }
                else if requirements.contains(.required) { baggage = .oversizedSeat }
                else { baggage = .withinLimit }
            } else {
                baggage = .needsMeasurement
            }
        default: baggage = .unanswered
        }
        let details = leg.reservation.details
        let hasRecordedDetails = [details.trainName, details.car, details.seat, details.confirmationNumber]
            .contains { !($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let focus: Focus
        if booking == nil { focus = .conditions }
        else if booking == .notBooked {
            switch baggage {
            case .none, .withinLimit, .oversizedSeat: focus = .reservation
            default: focus = .conditions
            }
        } else if booking == .booked {
            if baggage == .unanswered || baggage == .deferred || baggage == .needsMeasurement || baggage == .notAllowed {
                focus = .conditions
            } else if leg.reservation.statedBoarding == nil || (baggage == .oversizedSeat && details.oversizedSeatReserved == nil) {
                focus = .boarding
            } else { focus = .travelDay }
        } else { focus = .conditions }
        let origin = leg.origin.value ?? "—"
        let destination = leg.destination.value ?? "—"
        return Self(
            focus: focus,
            baggage: baggage,
            booking: booking,
            route: "\(origin) → \(destination)",
            date: leg.scheduledAt.value?.date?.displayString,
            boarding: leg.reservation.statedBoarding,
            hasRecordedDetails: hasRecordedDetails,
            oversizedSeatReserved: details.oversizedSeatReserved
        )
    }
}
