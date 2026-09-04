import Foundation

nonisolated extension Trip {
    var focusLegID: LegID? {
        if case .leg(let id) = currentContext.focus {
            return id
        }
        return nil
    }

    func focusLeg() throws -> Leg {
        guard let id = focusLegID, let leg = legs.first(where: { $0.id == id }) else {
            throw EngineError.noFocusLeg
        }
        return leg
    }

    func leg(id: LegID) throws -> Leg {
        guard let leg = legs.first(where: { $0.id == id }) else {
            throw EngineError.unknownLeg
        }
        return leg
    }

    mutating func updateLeg(id: LegID, _ body: (inout Leg) throws -> Void) throws {
        guard let index = legs.firstIndex(where: { $0.id == id }) else {
            throw EngineError.unknownLeg
        }
        try body(&legs[index])
    }

    func stay(id: StayID) throws -> Stay {
        guard let stay = stays.first(where: { $0.id == id }) else {
            throw EngineError.unknownStay
        }
        return stay
    }

    mutating func updateStay(id: StayID, _ body: (inout Stay) throws -> Void) throws {
        guard let index = stays.firstIndex(where: { $0.id == id }) else {
            throw EngineError.unknownStay
        }
        try body(&stays[index])
    }

    func activity(id: ActivityID) throws -> Activity {
        guard let activity = activities.first(where: { $0.id == id }) else {
            throw EngineError.unknownActivity
        }
        return activity
    }

    mutating func updateActivity(id: ActivityID, _ body: (inout Activity) throws -> Void) throws {
        guard let index = activities.firstIndex(where: { $0.id == id }) else {
            throw EngineError.unknownActivity
        }
        try body(&activities[index])
    }

    func bag(id: BagID) throws -> Bag {
        guard let bag = baggageInventory.first(where: { $0.id == id }) else {
            throw EngineError.unknownBag
        }
        return bag
    }

    mutating func updateBag(id: BagID, _ body: (inout Bag) throws -> Void) throws {
        guard let index = baggageInventory.firstIndex(where: { $0.id == id }) else {
            throw EngineError.unknownBag
        }
        try body(&baggageInventory[index])
    }
}
