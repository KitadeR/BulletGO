import Foundation

nonisolated enum QuestionCatalogLoader {
    static let productionResourceName = "shinkansen_questions_v1"

    static func loadProduction(from bundle: Bundle) throws -> QuestionCatalog {
        try load(from: bundle, resource: productionResourceName)
    }

    static func load(from bundle: Bundle, resource: String) throws -> QuestionCatalog {
        try load(
            data: BundleResource.jsonData(
                named: resource,
                in: bundle,
                subdirectories: ["Questions", "Resources/Questions", "Fixtures"]
            )
        )
    }

    static func load(data: Data) throws -> QuestionCatalog {
        let catalog: QuestionCatalog
        do {
            catalog = try JSONDecoder().decode(QuestionCatalog.self, from: data)
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.invalidCatalogVersion
        }
        try validate(catalog)
        return catalog
    }

    static func validate(_ catalog: QuestionCatalog) throws {
        guard catalog.catalogVersion >= 1 else {
            throw EngineError.invalidCatalogVersion
        }

        var seenIDs = Set<String>()
        var seenPriorities = Set<Int>()
        for question in catalog.questions {
            guard !question.id.rawValue.isEmpty, seenIDs.insert(question.id.rawValue).inserted else {
                throw EngineError.duplicateQuestionID(question.id.rawValue)
            }
            guard question.priority >= 0, seenPriorities.insert(question.priority).inserted else {
                throw EngineError.duplicateQuestionPriority(question.priority)
            }
            guard question.answerType == question.target.expectedAnswerType else {
                throw EngineError.inconsistentQuestion(question.id.rawValue)
            }
            guard expectedUIKind(for: question.answerType) == question.uiKind else {
                throw EngineError.inconsistentQuestion(question.id.rawValue)
            }
            if question.uiKind == .singleChoice {
                guard !question.choices.isEmpty else {
                    throw EngineError.missingQuestionChoices(question.id.rawValue)
                }
            } else if !question.choices.isEmpty {
                throw EngineError.inconsistentQuestion(question.id.rawValue)
            }
        }
    }

    private static func expectedUIKind(for answerType: QuestionAnswerType) -> QuestionUIKind {
        switch answerType {
        case .scheduledMoment: .dateTime
        case .baggageDimensions: .dimensions
        case .transportMode, .reservationStatus, .bookingService, .baggagePresence: .singleChoice
        }
    }
}
