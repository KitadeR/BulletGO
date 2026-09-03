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
