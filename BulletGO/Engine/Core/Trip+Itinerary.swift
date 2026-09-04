import Foundation

nonisolated extension Trip {
    mutating func insertTimelineItem(_ item: TripTimelineItem, at index: Int?) throws {
        let insertion = index ?? timeline.count
        guard (0...timeline.count).contains(insertion) else {
            throw EngineError.invalidTimelineIndex
        }
        timeline.insert(item, at: insertion)
    }

    mutating func removeTimelineItem(matching item: TripTimelineItem) {
        timeline.removeAll { $0 == item }
    }

    mutating func retargetFocusAfterRemovingLeg(_ removedID: LegID) {
        guard currentContext.focus == .leg(removedID) else {
            return
        }
        if let next = timeline.compactMap({ item -> LegID? in
            if case .leg(let id) = item { return id }
            return nil
        }).first {
            currentContext.focus = .leg(next)
        } else {
            currentContext.focus = .none
        }
    }

    mutating func focusNewLegIfNeeded(_ id: LegID) {
        if case .none = currentContext.focus {
            currentContext.focus = .leg(id)
        }
    }
}
