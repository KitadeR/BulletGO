import Foundation

nonisolated struct Trip: Hashable, Codable, Sendable {
    static let currentSchemaVersion = 5

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
    var savedPlaces: [SavedPlace]
    var notes: [ScopedNote]
    var attachments: [AttachmentRecord]
    var connectorEstimates: [ConnectorEstimate]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, schemaVersion, name, startDate, endDate, traveler
        case legs, stays, activities, timeline, baggageInventory
        case tasks, readinessChecks, currentContext, changeEvents
        case savedPlaces, notes, attachments, connectorEstimates
        case createdAt, updatedAt
    }

    init(
        id: TripID,
        schemaVersion: Int,
        name: Slot<String>,
        startDate: Slot<LocalDate>,
        endDate: Slot<LocalDate>,
        traveler: Traveler,
        legs: [Leg],
        stays: [Stay],
        activities: [Activity],
        timeline: [TripTimelineItem],
        baggageInventory: [Bag],
        tasks: [TripTask],
        readinessChecks: [ReadinessCheck],
        currentContext: CurrentContext,
        changeEvents: [TripChangeEvent],
        savedPlaces: [SavedPlace] = [],
        notes: [ScopedNote] = [],
        attachments: [AttachmentRecord] = [],
        connectorEstimates: [ConnectorEstimate] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.traveler = traveler
        self.legs = legs
        self.stays = stays
        self.activities = activities
        self.timeline = timeline
        self.baggageInventory = baggageInventory
        self.tasks = tasks
        self.readinessChecks = readinessChecks
        self.currentContext = currentContext
        self.changeEvents = changeEvents
        self.savedPlaces = savedPlaces
        self.notes = notes
        self.attachments = attachments
        self.connectorEstimates = connectorEstimates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(TripID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        name = try container.decode(Slot<String>.self, forKey: .name)
        startDate = try container.decode(Slot<LocalDate>.self, forKey: .startDate)
        endDate = try container.decode(Slot<LocalDate>.self, forKey: .endDate)
        traveler = try container.decode(Traveler.self, forKey: .traveler)
        legs = try container.decode([Leg].self, forKey: .legs)
        stays = try container.decodeIfPresent([Stay].self, forKey: .stays) ?? []
        activities = try container.decode([Activity].self, forKey: .activities)
        timeline = try container.decode([TripTimelineItem].self, forKey: .timeline)
        baggageInventory = try container.decode([Bag].self, forKey: .baggageInventory)
        tasks = try container.decode([TripTask].self, forKey: .tasks)
        readinessChecks = try container.decode([ReadinessCheck].self, forKey: .readinessChecks)
        currentContext = try container.decode(CurrentContext.self, forKey: .currentContext)
        changeEvents = try container.decode([TripChangeEvent].self, forKey: .changeEvents)
        savedPlaces = try container.decodeIfPresent([SavedPlace].self, forKey: .savedPlaces) ?? []
        notes = try container.decodeIfPresent([ScopedNote].self, forKey: .notes) ?? []
        attachments = try container.decodeIfPresent([AttachmentRecord].self, forKey: .attachments) ?? []
        connectorEstimates = try container.decodeIfPresent([ConnectorEstimate].self, forKey: .connectorEstimates) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func validate() throws {
        try Self.assertUnique(legs.map(\.id), error: .duplicateLegIDs)
        try Self.assertUnique(stays.map(\.id), error: .duplicateStayIDs)
        try Self.assertUnique(activities.map(\.id), error: .duplicateActivityIDs)
        try Self.assertUnique(baggageInventory.map(\.id), error: .duplicateBagIDs)
        try Self.assertUnique(tasks.map(\.id), error: .duplicateTaskIDs)
        try Self.assertUnique(readinessChecks.map(\.id), error: .duplicateReadinessCheckIDs)
        try Self.assertUnique(changeEvents.map(\.id), error: .duplicateChangeEventIDs)
        try Self.assertUnique(notes.map(\.id), error: .duplicateNoteIDs)
        try Self.assertUnique(attachments.map(\.id), error: .duplicateAttachmentIDs)
        try Self.assertUnique(savedPlaces.map(\.id), error: .duplicateSavedPlaceIDs)

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
