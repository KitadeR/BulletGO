import Foundation
@testable import BulletGO

enum PolicyScenarioSupport {
    static let now = DomainTestSupport.timestamp
    static let bagA = BagID(rawValue: UUID(uuidString: "B0A6A001-0000-4000-8000-000000000001")!)
    static let bagB = BagID(rawValue: UUID(uuidString: "B0A6A001-0000-4000-8000-000000000002")!)

    static func trip(
        transport: TransportMode? = .shinkansen,
        transportStatus: SlotStatus = .confirmed,
        dateConfirmed: Bool = true,
        reservation: ReservationStatus? = .notBooked,
        reservationSource: SlotSource = .userStated,
        service: BookingService? = nil,
        baggagePresence: BaggagePresence? = .yes,
        bags: [(BagID, BaggageDimensions?)] = []
    ) throws -> Trip {
        var trip = try DomainTestSupport.sampleTrip()
        let focusID = try trip.focusLeg()
        try trip.updateLeg(id: focusID.id) { leg in
            if let transport {
                switch transportStatus {
                case .confirmed:
                    leg.transportMode = try Slot.confirmed(value: transport, source: .userStated, updatedAt: now)
                case .inferred:
                    leg.transportMode = try Slot.inferred(value: transport, updatedAt: now)
                case .skipped:
                    leg.transportMode = try Slot.skipped(updatedAt: now)
                default:
                    leg.transportMode = try Slot.unknown(updatedAt: now)
                }
            }
            if dateConfirmed {
                leg.scheduledAt = try Slot.confirmed(
                    value: try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
                    source: .userStated,
                    updatedAt: now
                )
            }
            if let reservation {
                leg.reservation.status = try Slot.confirmed(
                    value: reservation,
                    source: reservationSource,
                    updatedAt: now
                )
            }
            if let service {
                leg.reservation.service = try Slot.confirmed(value: service, source: .userStated, updatedAt: now)
            }
            if let baggagePresence {
                leg.baggagePresence = try Slot.confirmed(value: baggagePresence, source: .userStated, updatedAt: now)
            }
            leg.bagIDs = bags.map(\.0)
            if transportStatus == .confirmed, transport != nil {
                leg.phase = .booking
            }
        }
        trip.baggageInventory = try bags.map { bagID, dimensions in
            let dimensionSlot: Slot<BaggageDimensions>
            if let dimensions {
                dimensionSlot = try Slot.confirmed(value: dimensions, source: .userStated, updatedAt: now)
            } else {
                dimensionSlot = try Slot.unknown(
                    collectionTiming: .justInTime(.baggagePolicyEvaluation),
                    updatedAt: now
                )
            }
            return Bag(
                id: bagID,
                kind: try Slot.unknown(updatedAt: now),
                userDescription: try Slot.unknown(updatedAt: now),
                perceivedSize: try Slot.unknown(updatedAt: now),
                dimensions: dimensionSlot,
                weightKilograms: try Slot.unknown(updatedAt: now),
                createdAt: now
            )
        }
        try trip.validate()
        return trip
    }

    static func dimensions(length: Double, width: Double, height: Double) throws -> BaggageDimensions {
        try BaggageDimensions(lengthCM: length, widthCM: width, heightCM: height)
    }
}
