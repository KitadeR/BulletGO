import Foundation

nonisolated struct Trip: Hashable, Codable, Sendable {
    static let currentSchemaVersion = 4

    let id: TripID
    var schemaVersion: Int
    var name: Slot<String>
    var startDate: Slot<LocalDate>
    var endDate: Slot<LocalDate>
    var traveler: Traveler
    var legs: [Leg]
    var stays: [Stay]
    var activities: [Activity]
    var timeline: [TripTimelineItem]
    var baggageInventory: [Bag]
    var tasks: [TripTask]
    var readinessChecks: [ReadinessCheck]
    var currentContext: CurrentContext
    var changeEvents: [TripChangeEvent]
    let createdAt: Date
    var updatedAt: Date

    func validate() throws {
        try Self.assertUnique(legs.map(\.id), error: .duplicateLegIDs)
        try Self.assertUnique(stays.map(\.id), error: .duplicateStayIDs)
        try Self.assertUnique(activities.map(\.id), error: .duplicateActivityIDs)
        try Self.assertUnique(baggageInventory.map(\.id), error: .duplicateBagIDs)
        try Self.assertUnique(tasks.map(\.id), error: .duplicateTaskIDs)
        try Self.assertUnique(readinessChecks.map(\.id), error: .duplicateReadinessCheckIDs)
        try Self.assertUnique(changeEvents.map(\.id), error: .duplicateChangeEventIDs)

        let legIDs = Set(legs.map(\.id))
        let stayIDs = Set(stays.map(\.id))
        let activityIDs = Set(activities.map(\.id))
        let bagIDs = Set(baggageInventory.map(\.id))
        var timelineLegs = Set<LegID>()
        var timelineStays = Set<StayID>()
        var timelineActivities = Set<ActivityID>()

        for item in timeline {
            switch item {
            case .leg(let id) where !legIDs.contains(id):
                throw TripValidationError.unresolvedTimelineItem(item)
            case .stay(let id) where !stayIDs.contains(id):
                throw TripValidationError.unresolvedTimelineItem(item)
            case .activity(let id) where !activityIDs.contains(id):
                throw TripValidationError.unresolvedTimelineItem(item)
            case .leg(let id):
                guard timelineLegs.insert(id).inserted else {
                    throw TripValidationError.unresolvedTimelineItem(item)
                }
            case .stay(let id):
                guard timelineStays.insert(id).inserted else {
                    throw TripValidationError.unresolvedTimelineItem(item)
                }
            case .activity(let id):
                guard timelineActivities.insert(id).inserted else {
                    throw TripValidationError.unresolvedTimelineItem(item)
                }
            }
        }

        guard timelineLegs == legIDs, timelineStays == stayIDs, timelineActivities == activityIDs else {
            throw TripValidationError.orphanItineraryItem
        }

        for leg in legs {
            for bagID in leg.bagIDs where !bagIDs.contains(bagID) {
                throw TripValidationError.bagNotInInventory(bagID)
            }
        }

        guard currentContext.tripID == id else {
            throw TripValidationError.currentContextTripMismatch
        }

        switch currentContext.focus {
        case .none:
            break
        case .leg(let focusID):
            guard legIDs.contains(focusID) else {
                throw TripValidationError.unresolvedCurrentFocus
            }
        case .stay(let focusID):
            guard stayIDs.contains(focusID) else {
                throw TripValidationError.unresolvedCurrentFocus
            }
        case .activity(let focusID):
            guard activityIDs.contains(focusID) else {
                throw TripValidationError.unresolvedCurrentFocus
            }
        }

        if let start = startDate.value, let end = endDate.value, start > end {
            throw TripValidationError.invertedTravelDates
        }
    }

    private static func assertUnique<ID: Hashable>(_ ids: [ID], error: TripValidationError) throws {
        guard Set(ids).count == ids.count else {
            throw error
        }
    }
}
