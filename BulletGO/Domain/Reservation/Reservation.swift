import Foundation

nonisolated enum ReservationStatus: String, Hashable, Codable, Sendable {
    case unknown
    case notBooked
    case booked
    case cancelled
}

nonisolated enum ReservationProgress: String, Hashable, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
}

nonisolated enum BookingService: String, Hashable, Codable, Sendable {
    case smartEX
    case klook
    case ticketMachine
    case other
}

nonisolated struct ReservationDetails: Hashable, Codable, Sendable {
    var origin: String?
    var destination: String?
    var departureDate: LocalDate?
    var departureTime: LocalTime?
    var arrivalTime: LocalTime?
    var trainName: String?
    var car: String?
    var seat: String?
}

nonisolated struct Reservation: Hashable, Codable, Sendable {
    let id: ReservationID
    var status: Slot<ReservationStatus>
    var service: Slot<BookingService>
    var progress: ReservationProgress
    var evidenceLevel: ReservationEvidenceLevel
    var evidenceHistory: [ReservationEvidenceRecord]
    var details: ReservationDetails
}
