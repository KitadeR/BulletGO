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
    var confirmationNumber: String?
    var providerName: String?
    var location: String?
    var notes: String?
    var startDate: LocalDate?
    var startTime: LocalTime?
    var endDate: LocalDate?
    var endTime: LocalTime?

    enum CodingKeys: String, CodingKey {
        case origin, destination, departureDate, departureTime, arrivalTime
        case trainName, car, seat
        case confirmationNumber, providerName, location, notes
        case startDate, startTime, endDate, endTime
    }

    init(
        origin: String? = nil,
        destination: String? = nil,
        departureDate: LocalDate? = nil,
        departureTime: LocalTime? = nil,
        arrivalTime: LocalTime? = nil,
        trainName: String? = nil,
        car: String? = nil,
        seat: String? = nil,
        confirmationNumber: String? = nil,
        providerName: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        startDate: LocalDate? = nil,
        startTime: LocalTime? = nil,
        endDate: LocalDate? = nil,
        endTime: LocalTime? = nil
    ) {
        self.origin = origin
        self.destination = destination
        self.departureDate = departureDate
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.trainName = trainName
        self.car = car
        self.seat = seat
        self.confirmationNumber = confirmationNumber
        self.providerName = providerName
        self.location = location
        self.notes = notes
        self.startDate = startDate
        self.startTime = startTime
        self.endDate = endDate
        self.endTime = endTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        destination = try container.decodeIfPresent(String.self, forKey: .destination)
        departureDate = try container.decodeIfPresent(LocalDate.self, forKey: .departureDate)
        departureTime = try container.decodeIfPresent(LocalTime.self, forKey: .departureTime)
        arrivalTime = try container.decodeIfPresent(LocalTime.self, forKey: .arrivalTime)
        trainName = try container.decodeIfPresent(String.self, forKey: .trainName)
        car = try container.decodeIfPresent(String.self, forKey: .car)
        seat = try container.decodeIfPresent(String.self, forKey: .seat)
        confirmationNumber = try container.decodeIfPresent(String.self, forKey: .confirmationNumber)
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startDate = try container.decodeIfPresent(LocalDate.self, forKey: .startDate)
        startTime = try container.decodeIfPresent(LocalTime.self, forKey: .startTime)
        endDate = try container.decodeIfPresent(LocalDate.self, forKey: .endDate)
        endTime = try container.decodeIfPresent(LocalTime.self, forKey: .endTime)
    }
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
