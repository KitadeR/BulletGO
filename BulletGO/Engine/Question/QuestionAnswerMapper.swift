import Foundation

nonisolated enum QuestionAnswerMapper {
    static func mutations(
        for question: QuestionSpec,
        answer: QuestionAnswer,
        trip: Trip
    ) throws -> [TripMutation] {
        let leg = try trip.focusLeg()
        switch (question.target, answer) {
        case (.legScheduledAt, .scheduledMoment(let moment)):
            return [.setLegScheduledAt(leg.id, moment)]
        case (.legTransportMode, .choice(let value)):
            guard let mode = TransportMode(rawValue: value) else {
                throw EngineError.invalidAnswer(value)
            }
            return [.setTransportMode(leg.id, mode)]
        case (.legReservationStatus, .choice(let value)):
            if value == "unsure" {
                return [.setReservationStatus(leg.id, nil, .skipped)]
            }
            guard let status = ReservationStatus(rawValue: value), status != .unknown else {
                throw EngineError.invalidAnswer(value)
            }
            return [.setReservationStatus(leg.id, status, .confirmed)]
        case (.legReservationStatus, .skip):
            return [.setReservationStatus(leg.id, nil, .skipped)]
        case (.legReservationService, .choice(let value)):
            guard let service = BookingService(rawValue: value) else {
                throw EngineError.invalidAnswer(value)
            }
            return [.setBookingService(leg.id, service)]
        case (.legBaggagePresence, .choice(let value)):
            switch value {
            case "yes":
                var mutations: [TripMutation] = [.setBaggagePresence(leg.id, .yes, .confirmed)]
                if leg.bagIDs.isEmpty {
                    mutations.append(.addBag(leg.id, BagID()))
                }
                return mutations
            case "no":
                return [.setBaggagePresence(leg.id, .no, .confirmed)]
            case "skip":
                return [.setBaggagePresence(leg.id, nil, .skipped)]
            default:
                throw EngineError.invalidAnswer(value)
            }
        case (.legBaggagePresence, .skip):
            return [.setBaggagePresence(leg.id, nil, .skipped)]
        case (.bagDimensions, .dimensions(let dimensions)):
            guard let bagID = bagNeedingDimensions(in: trip, leg: leg) else {
                throw EngineError.unknownBag
            }
            return [.setBagDimensions(bagID, dimensions)]
        case (_, .skip):
            throw EngineError.invalidAnswer("skip is not valid for \(question.id.rawValue)")
        default:
            throw EngineError.invalidAnswer(question.id.rawValue)
        }
    }

    private static func bagNeedingDimensions(in trip: Trip, leg: Leg) -> BagID? {
        leg.bagIDs.first { bagID in
            guard let bag = trip.baggageInventory.first(where: { $0.id == bagID }) else {
                return false
            }
            return !bag.dimensions.isSatisfiedForQuestioning
        } ?? leg.bagIDs.first
    }
}
