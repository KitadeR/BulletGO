import Foundation

nonisolated enum PackLoader {
    static let productionResourceName = "jr_shinkansen_oversized_baggage_v1"

    static func loadProduction(from bundle: Bundle) throws -> BaggagePolicyPack {
        try load(from: bundle, resource: productionResourceName)
    }

    static func load(from bundle: Bundle, resource: String) throws -> BaggagePolicyPack {
        try load(
            data: BundleResource.jsonData(
                named: resource,
                in: bundle,
                subdirectories: ["Packs", "Resources/Packs", "Fixtures"]
            )
        )
    }

    static func load(data: Data) throws -> BaggagePolicyPack {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let pack: BaggagePolicyPack
        do {
            pack = try decoder.decode(BaggagePolicyPack.self, from: data)
        } catch let error as EngineError {
            throw error
        } catch {
            throw unwrap(error) ?? EngineError.invalidPackVersion
        }
        try validate(pack)
        return pack
    }

    static func validate(_ pack: BaggagePolicyPack) throws {
        guard !pack.id.rawValue.isEmpty else {
            throw EngineError.invalidPackID
        }
        guard !pack.version.isEmpty else {
            throw EngineError.invalidPackVersion
        }
        if let until = pack.effectiveUntil, pack.effectiveFrom > until {
            throw EngineError.invalidPackDateRange
        }
        guard pack.totalSizeUpperBoundInclusiveCM > 0,
              pack.oversizedUpperBoundInclusiveCM > pack.totalSizeUpperBoundInclusiveCM
        else {
            throw EngineError.packBoundsOutOfOrder
        }
        guard pack.sourceURL.scheme?.lowercased() == "https" else {
            throw EngineError.packSourceMustBeHTTPS
        }
        for key in [
            BaggagePolicyPack.ReservationRequirement.notRequired.rawValue,
            BaggagePolicyPack.ReservationRequirement.required.rawValue,
            BaggagePolicyPack.ReservationRequirement.notAllowed.rawValue,
        ] where pack.results[key] == nil {
            throw EngineError.missingPackResult(key)
        }

        var actionKeys = Set<String>()
        for template in pack.actionTemplates {
            guard !template.purposeKey.isEmpty, actionKeys.insert(template.purposeKey).inserted else {
                throw EngineError.duplicatePackTemplate(template.purposeKey)
            }
        }
        var taskKeys = Set<String>()
        for template in pack.taskTemplates {
            guard !template.contentKey.isEmpty, taskKeys.insert(template.contentKey).inserted else {
                throw EngineError.duplicatePackTemplate(template.contentKey)
            }
        }
        guard !pack.appliesToTransport.isEmpty, !pack.resultKey.isEmpty else {
            throw EngineError.invalidPackVersion
        }
    }

    private static func unwrap(_ error: Error) -> EngineError? {
        if let engineError = error as? EngineError {
            return engineError
        }
        switch error as? DecodingError {
        case .dataCorrupted(let context),
             .keyNotFound(_, let context),
             .typeMismatch(_, let context),
             .valueNotFound(_, let context):
            if let underlying = context.underlyingError {
                return unwrap(underlying)
            }
            return nil
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }
}
