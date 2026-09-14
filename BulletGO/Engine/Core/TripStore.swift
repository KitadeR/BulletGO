import Foundation
import UniformTypeIdentifiers

struct StoreProcessResult: Sendable {
    var brain: BrainResult
    var receipt: MutationReceipt
}

actor TripStore {
    private let repository: any TripRepository
    private let brain: TripBrain
    private let attachments: (any AttachmentStoring)?

    init(
        repository: any TripRepository,
        brain: TripBrain,
        attachments: (any AttachmentStoring)? = nil
    ) {
        self.repository = repository
        self.brain = brain
        self.attachments = attachments
    }

    func fetchAll() async throws -> [Trip] {
        try await repository.fetchAll()
    }

    func fetch(id: TripID) async throws -> Trip? {
        try await repository.fetch(id: id)
    }

    func process(tripID: TripID, command: TypedCommand) async throws -> BrainResult {
        try await processDetailed(tripID: tripID, command: command).brain
    }

    func processDetailed(
        tripID: TripID,
        command: TypedCommand,
        orchestrateFiles: Bool = true
    ) async throws -> StoreProcessResult {
        guard let trip = try await repository.fetch(id: tripID) else {
            throw EngineError.tripNotFound
        }
        let receipt = MutationReceiptPlanner.plan(command, on: trip)
        if orchestrateFiles {
            try applyForwardFileEffects(receipt.fileEffects)
        }
        do {
            let result = try brain.process(trip: trip, command: command)
            try await repository.save(result.updatedTrip)
            return StoreProcessResult(brain: result, receipt: receipt)
        } catch {
            if orchestrateFiles {
                try rollbackForwardFileEffects(receipt.fileEffects)
            }
            throw error
        }
    }

    func undo(receipt: MutationReceipt) async throws -> BrainResult {
        guard !receipt.inverse.isEmpty || !receipt.fileEffects.isEmpty else {
            guard let trip = try await repository.fetch(id: receipt.tripID) else {
                throw EngineError.tripNotFound
            }
            return try brain.process(trip: trip, command: .reevaluate)
        }
        try applyUndoFileEffects(receipt.fileEffects)
        do {
            let command: TypedCommand = receipt.inverse.isEmpty ? .reevaluate : .applyMutations(receipt.inverse)
            return try await processDetailed(
                tripID: receipt.tripID,
                command: command,
                orchestrateFiles: false
            ).brain
        } catch {
            try rollbackUndoFileEffects(receipt.fileEffects)
            throw error
        }
    }

    func create(_ trip: Trip) async throws {
        try trip.validate()
        try await repository.save(trip)
    }

    func delete(id: TripID) async throws {
        try await repository.delete(id: id)
        try attachments?.deleteTripDirectory(tripID: id)
    }

    func importAttachment(
        tripID: TripID,
        data: Data,
        fileName: String,
        utType: UTType,
        scope: DomainScope
    ) async throws -> StoreProcessResult {
        guard let attachments else {
            throw EngineError.missingResource("attachments")
        }
        var record = try attachments.importData(
            data,
            tripID: tripID,
            fileName: fileName,
            utType: utType,
            scope: scope
        )
        record.scope = scope
        do {
            return try await processDetailed(tripID: tripID, command: .applyMutation(.addAttachment(record)))
        } catch {
            try? attachments.delete(record)
            throw error
        }
    }

    func importAttachment(
        tripID: TripID,
        from url: URL,
        fileName: String,
        utType: UTType,
        scope: DomainScope
    ) async throws -> StoreProcessResult {
        guard let attachments else {
            throw EngineError.missingResource("attachments")
        }
        var record = try attachments.importFile(
            from: url,
            tripID: tripID,
            fileName: fileName,
            utType: utType
        )
        record.scope = scope
        do {
            return try await processDetailed(tripID: tripID, command: .applyMutation(.addAttachment(record)))
        } catch {
            try? attachments.delete(record)
            throw error
        }
    }

    func removeAttachment(tripID: TripID, id: AttachmentID) async throws -> StoreProcessResult {
        try await processDetailed(tripID: tripID, command: .applyMutation(.removeAttachment(id)))
    }

    private func applyForwardFileEffects(_ effects: [AttachmentFileEffect]) throws {
        guard let attachments else { return }
        for effect in effects {
            if case .deleted(let record) = effect {
                try attachments.trash(record)
            }
        }
    }

    private func rollbackForwardFileEffects(_ effects: [AttachmentFileEffect]) throws {
        guard let attachments else { return }
        for effect in effects {
            switch effect {
            case .imported(let record):
                try? attachments.delete(record)
            case .deleted(let record):
                try? attachments.restore(record)
            }
        }
    }

    private func applyUndoFileEffects(_ effects: [AttachmentFileEffect]) throws {
        guard let attachments else { return }
        for effect in effects.reversed() {
            switch effect {
            case .imported(let record):
                try attachments.trash(record)
            case .deleted(let record):
                try attachments.restore(record)
            }
        }
    }

    private func rollbackUndoFileEffects(_ effects: [AttachmentFileEffect]) throws {
        guard let attachments else { return }
        for effect in effects.reversed() {
            switch effect {
            case .imported(let record):
                try? attachments.restore(record)
            case .deleted(let record):
                try? attachments.trash(record)
            }
        }
    }
}
