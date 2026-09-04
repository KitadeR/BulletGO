import Foundation

nonisolated enum EmptyTripFactory {
    static func make(
        name: String,
        startDate: LocalDate,
        endDate: LocalDate,
        preferredLanguage: String = "en",
        now: Date = Date()
    ) throws -> Trip {
        let tripID = TripID()
        let trip = Trip(
            id: tripID,
            schemaVersion: Trip.currentSchemaVersion,
            name: try Slot.confirmed(value: name, source: .userStated, updatedAt: now),
            startDate: try Slot.confirmed(value: startDate, source: .userStated, updatedAt: now),
            endDate: try Slot.confirmed(value: endDate, source: .userStated, updatedAt: now),
            traveler: Traveler(
                preferredLanguage: try Slot.confirmed(
                    value: preferredLanguage,
                    source: .userStated,
                    updatedAt: now
                ),
                partySize: try Slot.unknown(updatedAt: now),
                japanTravelExperience: try Slot.unknown(updatedAt: now)
            ),
            legs: [],
            stays: [],
            activities: [],
            timeline: [],
            baggageInventory: [],
            tasks: [],
            readinessChecks: [],
            currentContext: CurrentContext(tripID: tripID, focus: .none, tripPhase: .planning),
            changeEvents: [],
            createdAt: now,
            updatedAt: now
        )
        try trip.validate()
        return trip
    }
}

nonisolated enum ItineraryItemFactory {
    static func emptyReservation(at now: Date) throws -> Reservation {
        Reservation(
            id: ReservationID(),
            status: try Slot.unknown(updatedAt: now),
            service: try Slot.unknown(updatedAt: now),
            progress: .notStarted,
            evidenceLevel: .userStated,
            evidenceHistory: [],
            details: ReservationDetails()
        )
    }

    static func makeLeg(
        origin: String,
        destination: String,
        scheduledAt: ScheduledMoment? = nil,
        at now: Date
    ) throws -> Leg {
        Leg(
            id: LegID(),
            origin: try Slot.confirmed(value: origin, source: .userStated, updatedAt: now),
            destination: try Slot.confirmed(value: destination, source: .userStated, updatedAt: now),
            scheduledAt: try scheduledSlot(scheduledAt, at: now),
            transportMode: try Slot.unknown(updatedAt: now),
            partyCount: try Slot.unknown(updatedAt: now),
            baggagePresence: try Slot.unknown(updatedAt: now),
            seatPreference: try Slot.unknown(updatedAt: now),
            bagIDs: [],
            reservation: try emptyReservation(at: now),
            phase: .planning,
            policyEvaluations: [],
            activeProcedureIDs: []
        )
    }

    static func makeStay(
        place: String,
        checkIn: ScheduledMoment? = nil,
        checkOut: ScheduledMoment? = nil,
        at now: Date
    ) throws -> Stay {
        Stay(
            id: StayID(),
            place: try Slot.confirmed(value: place, source: .userStated, updatedAt: now),
            checkIn: try scheduledSlot(checkIn, at: now),
            checkOut: try scheduledSlot(checkOut, at: now),
            reservation: try emptyReservation(at: now)
        )
    }

    static func makeActivity(
        title: String,
        place: String,
        scheduledAt: ScheduledMoment? = nil,
        at now: Date
    ) throws -> Activity {
        Activity(
            id: ActivityID(),
            title: try Slot.confirmed(value: title, source: .userStated, updatedAt: now),
            type: try Slot.confirmed(value: .other, source: .userStated, updatedAt: now),
            scheduledAt: try scheduledSlot(scheduledAt, at: now),
            place: try Slot.confirmed(value: place, source: .userStated, updatedAt: now),
            reservation: try emptyReservation(at: now)
        )
    }

    private static func scheduledSlot(_ moment: ScheduledMoment?, at now: Date) throws -> Slot<ScheduledMoment> {
        if let moment {
            return try Slot.confirmed(value: moment, source: .userStated, updatedAt: now)
        }
        return try Slot.unknown(updatedAt: now)
    }
}
