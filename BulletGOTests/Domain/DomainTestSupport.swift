import Foundation
@testable import BulletGO

enum DomainTestSupport {
    static let timestamp = Date(timeIntervalSince1970: 1_788_393_600)
    static let timeZone = "Asia/Tokyo"

    static func unknownString() throws -> Slot<String> {
        try Slot.unknown(updatedAt: timestamp)
    }

    static func emptyReservation() throws -> Reservation {
        Reservation(
            id: ReservationID(),
            status: try Slot.unknown(updatedAt: timestamp),
            service: try Slot.unknown(updatedAt: timestamp),
            progress: .notStarted,
            evidenceLevel: .userStated,
            evidenceHistory: [],
            details: ReservationDetails()
        )
    }

    static func unknownTraveler() throws -> Traveler {
        Traveler(
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
        )
    }

    static func unknownMoment() throws -> Slot<ScheduledMoment> {
        try Slot.unknown(updatedAt: timestamp)
    }

    static func sampleTrip() throws -> Trip {
        let tripID = TripID()
        let tokyoKyoto = try leg(
            origin: "Tokyo",
            destination: "Kyoto",
            phase: .planning
        )
        let kyotoSightseeing = try activity(title: "Kinkaku-ji", place: "Kyoto")
        let kyotoOsaka = try leg(origin: "Kyoto", destination: "Osaka", phase: .planning)
        let osakaSightseeing = try activity(title: "Dotonbori", place: "Osaka")
        let osakaHakata = try leg(origin: "Osaka", destination: "Hakata", phase: .planning)
        let hakataSightseeing = try activity(title: "Hakata sightseeing", place: "Hakata")

        let start = try LocalDate(year: 2026, month: 10, day: 1)
        let end = try LocalDate(year: 2026, month: 10, day: 8)

        let trip = Trip(
            id: tripID,
            schemaVersion: 3,
            name: try Slot.inferred(value: "Japan trip", updatedAt: timestamp),
            startDate: try Slot.confirmed(value: start, source: .userStated, updatedAt: timestamp),
            endDate: try Slot.confirmed(value: end, source: .userStated, updatedAt: timestamp),
            traveler: try unknownTraveler(),
            legs: [tokyoKyoto, kyotoOsaka, osakaHakata],
            activities: [kyotoSightseeing, osakaSightseeing, hakataSightseeing],
            timeline: [
                .leg(tokyoKyoto.id),
                .activity(kyotoSightseeing.id),
                .leg(kyotoOsaka.id),
                .activity(osakaSightseeing.id),
                .leg(osakaHakata.id),
                .activity(hakataSightseeing.id),
            ],
            baggageInventory: [],
            tasks: [],
            readinessChecks: [],
            currentContext: CurrentContext(
                tripID: tripID,
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

    private static func leg(origin: String, destination: String, phase: LegPhase) throws -> Leg {
        Leg(
            id: LegID(),
            origin: try Slot.confirmed(value: origin, source: .userStated, updatedAt: timestamp),
            destination: try Slot.confirmed(value: destination, source: .userStated, updatedAt: timestamp),
            scheduledAt: try unknownMoment(),
            transportMode: try Slot.unknown(updatedAt: timestamp),
            partyCount: try Slot.unknown(updatedAt: timestamp),
            baggagePresence: try Slot.unknown(updatedAt: timestamp),
            seatPreference: try Slot.unknown(updatedAt: timestamp),
            bagIDs: [],
            reservation: try emptyReservation(),
            phase: phase,
            policyEvaluations: [],
            activeProcedureIDs: []
        )
    }

    private static func activity(title: String, place: String) throws -> Activity {
        Activity(
            id: ActivityID(),
            title: try Slot.confirmed(value: title, source: .userStated, updatedAt: timestamp),
            type: try Slot.confirmed(value: .sightseeing, source: .userStated, updatedAt: timestamp),
            scheduledAt: try unknownMoment(),
            place: try Slot.confirmed(value: place, source: .userStated, updatedAt: timestamp),
            reservation: try emptyReservation()
        )
    }
}
