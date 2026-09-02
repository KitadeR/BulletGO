import XCTest

final class BulletGOUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyTimelineOpensComingSoonFromFeatureHub() throws {
        let app = XCUIApplication()
        app.launch()

        let emptyState = app.descendants(matching: .any)["trip-timeline-empty"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))

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
