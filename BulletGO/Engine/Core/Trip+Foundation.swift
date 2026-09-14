import Foundation

extension Trip {
    nonisolated mutating func moveItem(_ item: TripTimelineItem, to date: LocalDate?, at now: Date) throws {
        switch item {
        case .leg(let id):
            try updateLeg(id: id) { leg in
                if let date {
                    let current = leg.scheduledAt.value
                    if let current {
                        let moved = try current.replacingDate(date)
                        leg.scheduledAt = try confirmed(leg.scheduledAt, moved, at: now)
                    } else {
                        let moment = try ScheduledMoment(
                            date: date,
                            timeZoneIdentifier: TripCalendar.timeZoneIdentifier
                        )
                        leg.scheduledAt = try confirmed(leg.scheduledAt, moment, at: now)
                    }
                    if let arrival = leg.arrivesAt.value, let oldDate = current?.date {
                        let offset = try arrival.date.map { try $0.daysFrom(oldDate) } ?? 0
                        let arrivalDate = try date.addingDays(offset)
                        leg.arrivesAt = try confirmed(leg.arrivesAt, try arrival.replacingDate(arrivalDate), at: now)
                    } else if let arrival = leg.arrivesAt.value, arrival.date == nil, arrival.hasScheduleContent {
                        leg.arrivesAt = try confirmed(leg.arrivesAt, try arrival.replacingDate(date), at: now)
                    }
                } else {
                    leg.scheduledAt = try TripMutationApplier.stripDate(from: leg.scheduledAt, at: now)
                    leg.arrivesAt = try TripMutationApplier.stripDate(from: leg.arrivesAt, at: now)
                }
            }
        case .stay(let id):
            try updateStay(id: id) { stay in
                if let date {
                    let checkIn = stay.checkIn.value
                    let duration: Int
                    if let start = checkIn?.date, let end = stay.checkOut.value?.date {
                        duration = LocalDate.dates(from: start, through: end).count - 1
                    } else {
                        duration = 0
                    }
                    let timeZone = checkIn?.timeZoneIdentifier ?? TripCalendar.timeZoneIdentifier
                    let newCheckIn = try ScheduledMoment(
                        date: date,
                        time: checkIn?.time,
                        timeZoneIdentifier: timeZone,
                        isAllDay: checkIn?.isAllDay ?? false
                    )
                    stay.checkIn = try confirmed(stay.checkIn, newCheckIn, at: now)
                    if duration > 0 || stay.checkOut.value != nil {
                        let checkOutDate = try date.addingDays(max(duration, 0))
                        let existingOut = stay.checkOut.value
                        stay.checkOut = try confirmed(
                            stay.checkOut,
                            try ScheduledMoment(
                                date: checkOutDate,
                                time: existingOut?.time,
                                timeZoneIdentifier: existingOut?.timeZoneIdentifier ?? timeZone,
                                isAllDay: existingOut?.isAllDay ?? false
                            ),
                            at: now
                        )
                    }
                } else {
                    stay.checkIn = try TripMutationApplier.stripDate(from: stay.checkIn, at: now)
                    stay.checkOut = try TripMutationApplier.stripDate(from: stay.checkOut, at: now)
                }
            }
        case .activity(let id):
            try updateActivity(id: id) { activity in
                if let date {
                    let previousStart = activity.scheduledAt.value
                    let previousEnd = activity.endsAt.value
                    if let current = activity.scheduledAt.value {
                        activity.scheduledAt = try confirmed(
                            activity.scheduledAt,
                            try current.replacingDate(date),
                            at: now
                        )
                    } else {
                        let moment = try ScheduledMoment(
                            date: date,
                            timeZoneIdentifier: TripCalendar.timeZoneIdentifier
                        )
                        activity.scheduledAt = try confirmed(activity.scheduledAt, moment, at: now)
                    }
                    if let previousEnd, let previousStart, let oldDate = previousStart.date {
                        let offset = try previousEnd.date.map { try $0.daysFrom(oldDate) } ?? 0
                        activity.endsAt = try confirmed(
                            activity.endsAt,
                            try previousEnd.replacingDate(try date.addingDays(offset)),
                            at: now
                        )
                    } else if let previousEnd, previousEnd.hasScheduleContent {
                        activity.endsAt = try confirmed(
                            activity.endsAt,
                            try previousEnd.replacingDate(date),
                            at: now
                        )
                    }
                } else {
                    activity.scheduledAt = try TripMutationApplier.stripDate(from: activity.scheduledAt, at: now)
                    activity.endsAt = try TripMutationApplier.stripDate(from: activity.endsAt, at: now)
                }
            }
        }

        guard date != nil, let from = timeline.firstIndex(of: item) else {
            return
        }
        timeline.remove(at: from)
        let insertion = insertionIndex(for: date, excluding: item)
        let clamped = min(max(insertion, 0), timeline.count)
        timeline.insert(item, at: clamped)
    }

    private nonisolated func insertionIndex(for date: LocalDate?, excluding item: TripTimelineItem) -> Int {
        guard let date else {
            return timeline.count
        }
        var last = -1
        for (index, existing) in timeline.enumerated() where existing != item {
            if assignmentDate(for: existing) == date {
                last = index
            }
        }
        if last >= 0 {
            return last + 1
        }
        return timeline.count
    }

    nonisolated func assignmentDate(for item: TripTimelineItem) -> LocalDate? {
        switch item {
        case .leg(let id):
            legs.first { $0.id == id }?.scheduledAt.value?.date
        case .stay(let id):
            stays.first { $0.id == id }?.checkIn.value?.date
        case .activity(let id):
            activities.first { $0.id == id }?.scheduledAt.value?.date
        }
    }

    nonisolated mutating func replaceReservation(in scope: DomainScope, details: ReservationDetails? = nil, status: (ReservationStatus, SlotStatus)? = nil, at now: Date) throws {
        switch scope {
        case .trip:
            throw EngineError.invalidAnswer("trip-scoped reservation is not supported")
        case .leg(let id):
            try updateLeg(id: id) { leg in
                if let details {
                    leg.reservation.details = details
                }
                if let status {
                    leg.reservation.status = try updatedReservationStatus(leg.reservation.status, status: status, at: now)
                }
            }
        case .stay(let id):
            try updateStay(id: id) { stay in
                if let details {
                    stay.reservation.details = details
                }
                if let status {
                    stay.reservation.status = try updatedReservationStatus(stay.reservation.status, status: status, at: now)
                }
            }
        case .activity(let id):
            try updateActivity(id: id) { activity in
                if let details {
                    activity.reservation.details = details
                }
                if let status {
                    activity.reservation.status = try updatedReservationStatus(activity.reservation.status, status: status, at: now)
                }
            }
        }
    }
}

extension LocalDate {
    nonisolated func daysFrom(_ other: LocalDate) throws -> Int {
        let dates = self <= other
            ? LocalDate.dates(from: self, through: other)
            : LocalDate.dates(from: other, through: self)
        let delta = dates.count - 1
        return self >= other ? delta : -delta
    }
}

private nonisolated func confirmed(
    _ slot: Slot<ScheduledMoment>,
    _ moment: ScheduledMoment,
    at now: Date
) throws -> Slot<ScheduledMoment> {
    try slot.updating(
        value: moment,
        status: .confirmed,
        source: .userStated,
        confidence: .high,
        at: now
    )
}

private nonisolated func updatedReservationStatus(
    _ slot: Slot<ReservationStatus>,
    status: (ReservationStatus, SlotStatus),
    at now: Date
) throws -> Slot<ReservationStatus> {
    try slot.updating(
        value: status.1 == .confirmed ? status.0 : nil,
        status: status.1,
        source: .userStated,
        confidence: status.1 == .confirmed ? .high : nil,
        at: now
    )
}
