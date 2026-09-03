import Foundation

nonisolated enum ReferenceTripIdentity {
    static let trip = TripID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000001"))
    static let tokyoKyoto = LegID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000011"))
    static let kyotoOsaka = LegID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000012"))
    static let osakaHakata = LegID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000013"))
    static let kinkakuji = ActivityID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000021"))
    static let dotonbori = ActivityID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000022"))
    static let hakataSightseeing = ActivityID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000023"))
    static let tokyoKyotoReservation = ReservationID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000031"))
    static let kyotoOsakaReservation = ReservationID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000032"))
    static let osakaHakataReservation = ReservationID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000033"))
    static let kinkakujiReservation = ReservationID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000041"))
    static let dotonboriReservation = ReservationID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000042"))
    static let hakataReservation = ReservationID(rawValue: uuid("A1E0B001-0000-4000-8000-000000000043"))

    private static func uuid(_ string: String) -> UUID {
        guard let value = UUID(uuidString: string) else {
            preconditionFailure("Invalid reference trip UUID: \(string)")
        }
        return value
    }
}

nonisolated struct ReferenceTripFactory: Sendable {
    var now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    func makeReferenceTrip() throws -> Trip {
        let timestamp = now()
        let tokyoKyoto = try leg(
            id: ReferenceTripIdentity.tokyoKyoto,
            reservationID: ReferenceTripIdentity.tokyoKyotoReservation,
            origin: "Tokyo",
            destination: "Kyoto",
            updatedAt: timestamp
        )
        let kyotoOsaka = try leg(
            id: ReferenceTripIdentity.kyotoOsaka,
            reservationID: ReferenceTripIdentity.kyotoOsakaReservation,
            origin: "Kyoto",
            destination: "Osaka",
            updatedAt: timestamp
        )
        let osakaHakata = try leg(
            id: ReferenceTripIdentity.osakaHakata,
            reservationID: ReferenceTripIdentity.osakaHakataReservation,
            origin: "Osaka",
            destination: "Hakata",
            updatedAt: timestamp
        )
        let kinkakuji = try activity(
            id: ReferenceTripIdentity.kinkakuji,
            reservationID: ReferenceTripIdentity.kinkakujiReservation,
            title: "Kinkaku-ji",
            place: "Kyoto",
            updatedAt: timestamp
        )
        let dotonbori = try activity(
            id: ReferenceTripIdentity.dotonbori,
            reservationID: ReferenceTripIdentity.dotonboriReservation,
            title: "Dotonbori",
            place: "Osaka",
            updatedAt: timestamp
        )
        let hakataSightseeing = try activity(
            id: ReferenceTripIdentity.hakataSightseeing,
            reservationID: ReferenceTripIdentity.hakataReservation,
            title: "Hakata sightseeing",
            place: "Hakata",
            updatedAt: timestamp
        )

        let trip = Trip(
            id: ReferenceTripIdentity.trip,
            schemaVersion: 3,
            name: try Slot.inferred(value: "Japan trip", updatedAt: timestamp),
            startDate: try Slot.confirmed(
                value: LocalDate(year: 2026, month: 10, day: 1),
                source: .userStated,
                updatedAt: timestamp
            ),
            endDate: try Slot.confirmed(
                value: LocalDate(year: 2026, month: 10, day: 8),
                source: .userStated,
                updatedAt: timestamp
            ),
            traveler: Traveler(
                preferredLanguage: try Slot.confirmed(
                    value: "en",
                    source: .userStated,
                    updatedAt: timestamp
                ),
                partySize: try Slot.unknown(updatedAt: timestamp),
                japanTravelExperience: try Slot.inferred(
                    value: .firstTime,
                    updatedAt: timestamp
                )
            ),
            legs: [tokyoKyoto, kyotoOsaka, osakaHakata],
            activities: [kinkakuji, dotonbori, hakataSightseeing],
            timeline: [
                .leg(tokyoKyoto.id),
                .activity(kinkakuji.id),
                .leg(kyotoOsaka.id),
                .activity(dotonbori.id),
                .leg(osakaHakata.id),
                .activity(hakataSightseeing.id),
            ],
            baggageInventory: [],
            tasks: [],
            readinessChecks: [],
            currentContext: CurrentContext(
                tripID: ReferenceTripIdentity.trip,
                focus: .leg(tokyoKyoto.id),
                tripPhase: .planning
            ),
            changeEvents: [],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try trip.validate()
        return trip
    }

    private func leg(
        id: LegID,
        reservationID: ReservationID,
        origin: String,
        destination: String,
        updatedAt: Date
    ) throws -> Leg {
        Leg(
            id: id,
            origin: try Slot.confirmed(value: origin, source: .userStated, updatedAt: updatedAt),
            destination: try Slot.confirmed(value: destination, source: .userStated, updatedAt: updatedAt),
            scheduledAt: try Slot.unknown(updatedAt: updatedAt),
            transportMode: try Slot.unknown(updatedAt: updatedAt),
            partyCount: try Slot.unknown(updatedAt: updatedAt),
            baggagePresence: try Slot.unknown(updatedAt: updatedAt),
            seatPreference: try Slot.unknown(updatedAt: updatedAt),
            bagIDs: [],
            reservation: try emptyReservation(id: reservationID, updatedAt: updatedAt),
            phase: .planning,
            policyEvaluations: [],
            activeProcedureIDs: []
        )
    }

    private func activity(
        id: ActivityID,
        reservationID: ReservationID,
        title: String,
        place: String,
        updatedAt: Date
    ) throws -> Activity {
        Activity(
            id: id,
            title: try Slot.confirmed(value: title, source: .userStated, updatedAt: updatedAt),
            type: try Slot.confirmed(value: .sightseeing, source: .userStated, updatedAt: updatedAt),
            scheduledAt: try Slot.unknown(updatedAt: updatedAt),
            place: try Slot.confirmed(value: place, source: .userStated, updatedAt: updatedAt),
            reservation: try emptyReservation(id: reservationID, updatedAt: updatedAt)
        )
    }

    private func emptyReservation(id: ReservationID, updatedAt: Date) throws -> Reservation {
        Reservation(
            id: id,
            status: try Slot.unknown(updatedAt: updatedAt),
            service: try Slot.unknown(updatedAt: updatedAt),
            progress: .notStarted,
            evidenceLevel: .userStated,
            evidenceHistory: [],
            details: ReservationDetails()
        )
    }
}
