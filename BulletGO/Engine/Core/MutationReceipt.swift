import Foundation

nonisolated struct MutationReceipt: Equatable, Sendable {
    var tripID: TripID
    var inverse: [TripMutation]
    var fileEffects: [AttachmentFileEffect]
}

nonisolated enum AttachmentFileEffect: Equatable, Sendable {
    case imported(AttachmentRecord)
    case deleted(AttachmentRecord)
}

nonisolated enum MutationReceiptPlanner {
    static func plan(_ command: TypedCommand, on trip: Trip) -> MutationReceipt {
        let mutations: [TripMutation]
        switch command {
        case .applyMutation(let mutation):
            mutations = [mutation]
        case .applyMutations(let values):
            mutations = values
        default:
            return MutationReceipt(tripID: trip.id, inverse: [], fileEffects: [])
        }
        return plan(mutations, on: trip)
    }

    static func plan(_ mutations: [TripMutation], on trip: Trip) -> MutationReceipt {
        var inverse: [TripMutation] = []
        var files: [AttachmentFileEffect] = []
        for mutation in mutations {
            let planned = plan(mutation, on: trip)
            inverse.insert(contentsOf: planned.inverse, at: 0)
            files.append(contentsOf: planned.fileEffects)
        }
        return MutationReceipt(tripID: trip.id, inverse: inverse, fileEffects: files)
    }

    static func plan(_ mutation: TripMutation, on trip: Trip) -> MutationReceipt {
        switch mutation {
        case .moveTimelineItem(let from, let to):
            guard trip.timeline.indices.contains(from) else {
                return MutationReceipt(tripID: trip.id, inverse: [], fileEffects: [])
            }
            let item = trip.timeline[from]
            return MutationReceipt(
                tripID: trip.id,
                inverse: [.moveTimelineItemID(item, toIndex: inverseTimelineIndex(from: from, to: to))],
                fileEffects: []
            )
        case .moveTimelineItemID(let item, let toIndex):
            let from = trip.timeline.firstIndex(of: item) ?? 0
            return MutationReceipt(
                tripID: trip.id,
                inverse: [.moveTimelineItemID(item, toIndex: inverseTimelineIndex(from: from, to: toIndex))],
                fileEffects: []
            )
        case .moveItemToDate(let item, _):
            let previous = trip.assignmentDate(for: item)
            let index = trip.timeline.firstIndex(of: item) ?? 0
            return MutationReceipt(
                tripID: trip.id,
                inverse: [.moveItemToDate(item, previous), .moveTimelineItemID(item, toIndex: index)],
                fileEffects: []
            )
        case .removeLeg(let id):
            return restoreReceipt(TripScopedDataPurger.captureBundle(for: .leg(id), in: trip), tripID: trip.id)
        case .removeStay(let id):
            return restoreReceipt(TripScopedDataPurger.captureBundle(for: .stay(id), in: trip), tripID: trip.id)
        case .removeActivity(let id):
            return restoreReceipt(TripScopedDataPurger.captureBundle(for: .activity(id), in: trip), tripID: trip.id)
        case .addAttachment(let record):
            return MutationReceipt(
                tripID: trip.id,
                inverse: [.removeAttachment(record.id)],
                fileEffects: [.imported(record)]
            )
        case .removeAttachment(let id):
            guard let record = trip.attachments.first(where: { $0.id == id }) else {
                return MutationReceipt(tripID: trip.id, inverse: [], fileEffects: [])
            }
            return MutationReceipt(
                tripID: trip.id,
                inverse: [.addAttachment(record)],
                fileEffects: [.deleted(record)]
            )
        case .cacheConnectorEstimate:
            return MutationReceipt(tripID: trip.id, inverse: [], fileEffects: [])
        default:
            return MutationReceipt(tripID: trip.id, inverse: [], fileEffects: [])
        }
    }

    private static func restoreReceipt(_ bundle: DeletedItineraryItemBundle, tripID: TripID) -> MutationReceipt {
        MutationReceipt(
            tripID: tripID,
            inverse: [.restoreItineraryItem(bundle)],
            fileEffects: bundle.attachments.map { .deleted($0) }
        )
    }

    private static func inverseTimelineIndex(from: Int, to: Int) -> Int {
        to < from ? from + 1 : from
    }
}
