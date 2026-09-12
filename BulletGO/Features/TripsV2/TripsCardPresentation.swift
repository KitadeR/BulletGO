import Foundation

nonisolated struct TripsLegCardPresentation: Equatable, Sendable {
    var transport: DisplayText
    var route: String
    var arrivalTimeText: String?
    var trainName: String?
    var action: TripsPreparationIndication?
    var destination: AppRoute?

    var hasReservationMeta: Bool {
        arrivalTimeText != nil || !(trainName?.isEmpty ?? true)
    }
}

nonisolated struct TripsActivityCardPresentation: Equatable, Sendable {
    var title: String
    var place: String?
    var isBooked: Bool
    var destination: AppRoute?
}

nonisolated struct TripsStayCardPresentation: Equatable, Sendable {
    var name: String
    var role: StayPresentationRole
    var nights: Int?
    var dateRange: String?
    var destination: AppRoute?
}

nonisolated enum TripsLegCardComposer {
    static func presentation(
        row: TimelineRow,
        trip: Trip,
        catalog: QuestionCatalog?
    ) -> TripsLegCardPresentation? {
        guard case .leg(let id) = row.id, let leg = trip.legs.first(where: { $0.id == id }) else {
            return nil
        }
        let meta = reservationMeta(leg.reservation)
        return TripsLegCardPresentation(
            transport: .localized(TripContentResolver.transportSummary(for: leg)),
            route: row.title,
            arrivalTimeText: meta.arrival,
            trainName: meta.trainName,
            action: TripsPreparationComposer.indication(for: row, trip: trip, catalog: catalog),
            destination: row.destination
        )
    }

    /// Arrival / train name only when the reservation is confirmed booked and those
    /// fields actually exist. Empty factory reservations must not invent a train.
    private static func reservationMeta(_ reservation: Reservation) -> (arrival: String?, trainName: String?) {
        guard reservation.status.status == .confirmed, reservation.status.value == .booked else {
            return (nil, nil)
        }
        let arrival: String?
        if let time = reservation.details.arrivalTime {
            arrival = String(format: "%02d:%02d", time.hour, time.minute)
        } else {
            arrival = nil
        }
        let train = reservation.details.trainName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (arrival, (train?.isEmpty == false) ? train : nil)
    }
}

nonisolated enum TripsActivityCardComposer {
    static func presentation(row: TimelineRow, trip: Trip) -> TripsActivityCardPresentation? {
        guard case .activity(let id) = row.id,
              let activity = trip.activities.first(where: { $0.id == id })
        else {
            return nil
        }
        let title = activity.title.value ?? row.title
        let place = confirmedText(activity.place)
        let placeIfDistinct = (place != title) ? place : nil
        return TripsActivityCardPresentation(
            title: title,
            place: placeIfDistinct,
            isBooked: isConfirmedBooked(activity.reservation),
            destination: row.destination
        )
    }
}

nonisolated enum TripsStayCardComposer {
    static func presentation(
        row: TimelineRow,
        trip: Trip,
        locale: Locale
    ) -> TripsStayCardPresentation? {
        guard case .stay(let id, let role) = row.id,
              let stay = trip.stays.first(where: { $0.id == id })
        else {
            return nil
        }
        let checkInDate = confirmedDate(stay.checkIn)
        let checkOutDate = confirmedDate(stay.checkOut)
        let nights: Int?
        let dateRange: String?
        if let checkInDate, let checkOutDate {
            nights = TripsV2Formatting.nights(from: checkInDate, to: checkOutDate)
            dateRange = TripsV2Formatting.stayDateRange(from: checkInDate, to: checkOutDate, locale: locale)
        } else {
            nights = nil
            dateRange = nil
        }
        return TripsStayCardPresentation(
            name: stay.place.value ?? row.title,
            role: role,
            nights: nights,
            dateRange: dateRange,
            destination: row.destination
        )
    }
}

nonisolated private func isConfirmedBooked(_ reservation: Reservation) -> Bool {
    reservation.status.status == .confirmed && reservation.status.value == .booked
}

nonisolated private func confirmedText(_ slot: Slot<String>) -> String? {
    guard slot.status == .confirmed else {
        return nil
    }
    let value = slot.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? nil : value
}

nonisolated private func confirmedDate(_ slot: Slot<ScheduledMoment>) -> LocalDate? {
    guard slot.status == .confirmed else {
        return nil
    }
    return slot.value?.date
}
