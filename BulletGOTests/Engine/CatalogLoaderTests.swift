import Foundation
import Testing
@testable import BulletGO

@MainActor
struct CatalogLoaderTests {
    @Test func productionCatalogLoadsFromAppBundle() throws {
        let catalog = try QuestionCatalogLoader.loadProduction(from: .main)
        #expect(catalog.catalogVersion == 1)
        #expect(catalog.questions.map(\.id) == [
            .legDate,
            .transport,
            .ticketStatus,
            .selectService,
            .luggagePresence,
            .baggageDimensions,
        ])
        #expect(catalog.spec(id: .selectService)?.when == .reservationStatusIs(.notBooked))
        #expect(catalog.spec(id: .luggagePresence)?.when == .transportIs(.shinkansen))
        #expect(catalog.spec(id: .baggageDimensions)?.when == .policyNeedsDimensions)
    }

    @Test func productionPackLoadsFromAppBundle() throws {
        let pack = try PackLoader.loadProduction(from: .main)
        #expect(pack.id == .jrShinkansenOversizedBaggage)
        #expect(pack.totalSizeUpperBoundInclusiveCM == 160)
        #expect(pack.oversizedUpperBoundInclusiveCM == 250)
        #expect(pack.sourceURL.scheme == "https")
        #expect(pack.requirement(forTotalCM: 160) == .notRequired)
        #expect(pack.requirement(forTotalCM: 161) == .required)
        #expect(pack.requirement(forTotalCM: 250) == .required)
        #expect(pack.requirement(forTotalCM: 251) == .notAllowed)
    }

    @Test func brokenCatalogInTestBundleIsRejected() {
        #expect(throws: EngineError.duplicateQuestionID("q_dup")) {
            try QuestionCatalogLoader.load(from: EngineTestSupport.testBundle(), resource: "invalid_questions")
        }
    }

    @Test func brokenPackInTestBundleIsRejected() {
        #expect(throws: EngineError.packBoundsOutOfOrder) {
            try PackLoader.load(from: EngineTestSupport.testBundle(), resource: "invalid_pack")
        }
    }

    @Test func packRejectsNonHTTPSSource() throws {
        var json = try JSONSerialization.jsonObject(
            with: BundleResource.jsonData(
                named: PackLoader.productionResourceName,
                in: .main,
                subdirectories: ["Packs", "Resources/Packs"]
            )
        ) as! [String: Any]
        json["sourceURL"] = "http://global.jr-central.co.jp/en/info/oversized-baggage/index.html"
        json["totalSizeUpperBoundInclusiveCM"] = 160
        json["oversizedUpperBoundInclusiveCM"] = 250
        #expect(throws: EngineError.packSourceMustBeHTTPS) {
            try PackLoader.load(data: JSONSerialization.data(withJSONObject: json))
        }
    }
}
