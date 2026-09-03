import XCTest

final class BulletGOUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSeededTimelineShowsJourneyAndOpensLegDetail() throws {
        let app = XCUIApplication()
        app.launch()

        let timeline = app.descendants(matching: .any)["trip-timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 10))

        XCTAssertTrue(app.staticTexts["Tokyo → Kyoto"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kinkaku-ji"].exists)
        XCTAssertTrue(app.staticTexts["Kyoto → Osaka"].exists)
        XCTAssertTrue(app.staticTexts["Dotonbori"].exists)
        XCTAssertTrue(app.staticTexts["Osaka → Hakata"].exists)
        XCTAssertTrue(app.staticTexts["Hakata sightseeing"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["coming-up-section"].exists)

        let tokyoKyoto = app.descendants(matching: .any)["timeline-leg-A1E0B001-0000-4000-8000-000000000011"]
        XCTAssertTrue(tokyoKyoto.waitForExistence(timeout: 5))
        tokyoKyoto.tap()

        let detail = app.descendants(matching: .any)["leg-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tokyo → Kyoto"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["remembered-section"].exists)
    }

    @MainActor
    func testFeatureHubStillOpensComingSoonFromTimeline() throws {
        let app = XCUIApplication()
        app.launch()

        let timeline = app.descendants(matching: .any)["trip-timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 10))

        let openFeatureHub = app.buttons["open-feature-hub"]
        XCTAssertTrue(openFeatureHub.waitForExistence(timeout: 5))
        openFeatureHub.tap()

        let featureHub = app.descendants(matching: .any)["feature-hub-list"]
        XCTAssertTrue(featureHub.waitForExistence(timeout: 5))

        let baggageRow = app.descendants(matching: .any)["feature-row-baggage_check"]
        XCTAssertTrue(baggageRow.waitForExistence(timeout: 5))
        baggageRow.tap()

        let comingSoon = app.descendants(matching: .any)["coming-soon-view"]
        XCTAssertTrue(comingSoon.waitForExistence(timeout: 5))
    }
}
