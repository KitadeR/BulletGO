import Foundation

extension Trip {
    nonisolated mutating func moveItem(_ item: TripTimelineItem, to date: LocalDate?, at now: Date) throws {
        switch item {
        case .leg(let id):
            if let date {
                try updateLeg(id: id) { leg in
                    let current = leg.scheduledAt.value
                    if let current {
                        let moved = try current.replacingDate(date)
                        leg.scheduledAt = try leg.scheduledAt.updating(
                            value: moved,
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    } else {
                        let timeZone = TimeZone(identifier: "GMT")!.identifier
                        let moment = try ScheduledMoment(date: date, timeZoneIdentifier: timeZone)
                        leg.scheduledAt = try leg.scheduledAt.updating(
                            value: moment,
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    }
                    if let arrival = leg.arrivesAt.value, let oldDate = current?.date {
                        let offset = try arrival.date.daysFrom(oldDate)
                        let arrivalDate = try date.addingDays(offset)
                        leg.arrivesAt = try leg.arrivesAt.updating(
                            value: try arrival.replacingDate(arrivalDate),
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    }
                }
            } else {
                try updateLeg(id: id) { leg in
                    leg.scheduledAt = try leg.scheduledAt.updating(
                        value: nil,
                        status: .unknown,
                        source: .userStated,
                        confidence: nil,
                        at: now
                    )
                    leg.arrivesAt = try leg.arrivesAt.updating(
                        value: nil,
                        status: .unknown,
                        source: .userStated,
                        confidence: nil,
                        at: now
                    )
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
                    let timeZone = checkIn?.timeZoneIdentifier ?? TimeZone(identifier: "GMT")!.identifier
                    let newCheckIn = try ScheduledMoment(
                        date: date,
                        time: checkIn?.time,
                        timeZoneIdentifier: timeZone,
                        endTime: checkIn?.endTime,
                        isAllDay: checkIn?.isAllDay ?? false
                    )
                    stay.checkIn = try stay.checkIn.updating(
                        value: newCheckIn,
                        status: .confirmed,
                        source: .userStated,
                        confidence: .high,
                        at: now
                    )
                    if duration > 0 || stay.checkOut.value != nil {
                        let checkOutDate = try date.addingDays(max(duration, 0))
                        let existingOut = stay.checkOut.value
                        stay.checkOut = try stay.checkOut.updating(
                            value: try ScheduledMoment(
                                date: checkOutDate,
                                time: existingOut?.time,
                                timeZoneIdentifier: existingOut?.timeZoneIdentifier ?? timeZone,
                                endTime: existingOut?.endTime,
                                isAllDay: existingOut?.isAllDay ?? false
                            ),
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    }
                } else {
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
            }
        case .activity(let id):
            try updateActivity(id: id) { activity in
                if let date {
                    let previousStart = activity.scheduledAt.value
                    let previousEnd = activity.endsAt.value
                    if let current = activity.scheduledAt.value {
                        activity.scheduledAt = try activity.scheduledAt.updating(
                            value: try current.replacingDate(date),
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    } else {
                        let moment = try ScheduledMoment(
                            date: date,
                            timeZoneIdentifier: TimeZone(identifier: "GMT")!.identifier
                        )
                        activity.scheduledAt = try activity.scheduledAt.updating(
                            value: moment,
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    }
                    if let previousEnd, let previousStart {
                        let offset = try previousEnd.date.daysFrom(previousStart.date)
                        activity.endsAt = try activity.endsAt.updating(
                            value: try previousEnd.replacingDate(try date.addingDays(offset)),
                            status: .confirmed,
                            source: .userStated,
                            confidence: .high,
                            at: now
                        )
                    }
                } else {
                    activity.scheduledAt = try activity.scheduledAt.updating(
                        value: nil,
                        status: .unknown,
                        source: .userStated,
                        confidence: nil,
                        at: now
                    )
                    activity.endsAt = try activity.endsAt.updating(
                        value: nil,
                        status: .unknown,
                        source: .userStated,
                        confidence: nil,
                        at: now
                    )
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
