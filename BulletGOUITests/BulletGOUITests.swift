import XCTest

final class BulletGOUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeHasNoFeatureCatalogAndOpensJourney() throws {
        let app = launchApp()

        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["open-feature-hub"].exists)
        XCTAssertFalse(app.buttons["Features"].exists)

        openTokyoKyoto(in: app)
        XCTAssertTrue(element(app, "start-guidance").exists)
    }

    @MainActor
    func testGuidanceCloseReturnsToJourney() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "start-guidance")
        XCTAssertTrue(element(app, "guidance-sheet").waitForExistence(timeout: 5))
        tapID(app, "guidance-close")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 5))
    }

    @MainActor
    func testVerticalSliceFromTalkToBaggageResult() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "start-guidance")
        enterReferenceTalk(in: app)
        tapID(app, "guidance-continue")
        XCTAssertTrue(element(app, "guidance-question").waitForExistence(timeout: 10))
        tapID(app, "date-confirm")
        tapID(app, "question-choice-notBooked")
        tapID(app, "question-choice-yes")

        XCTAssertTrue(element(app, "now-section").waitForExistence(timeout: 10))
        tapID(app, "now-task-capture_dimensions")

        XCTAssertTrue(element(app, "task-detail").waitForExistence(timeout: 5))
        tapID(app, "task-primary-action")

        XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 5))
        fillBaggage(in: app, length: "80", width: "40", height: "41")
        tapID(app, "baggage-submit")
        XCTAssertTrue(element(app, "baggage-result").waitForExistence(timeout: 8))
    }

    @MainActor
    func testBookingMethodComingSoonStaysInContext() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "start-guidance")
        enterReferenceTalk(in: app)
        tapID(app, "guidance-continue")
        XCTAssertTrue(element(app, "guidance-question").waitForExistence(timeout: 10))
        tapID(app, "date-confirm")
        tapID(app, "question-choice-notBooked")
        tapID(app, "question-choice-yes")
        tapID(app, "now-task-select_booking_method", timeout: 10)
        XCTAssertTrue(element(app, "task-detail").waitForExistence(timeout: 5))
        tapID(app, "task-primary-action")
        XCTAssertTrue(element(app, "coming-soon-view").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "feature-hub-list").exists)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    @MainActor
    private func openTokyoKyoto(in app: XCUIApplication) {
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 15))
        tapID(app, "timeline-leg-A1E0B001-0000-4000-8000-000000000011")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 8))
    }

    @MainActor
    private func enterReferenceTalk(in app: XCUIApplication) {
        let input = app.textViews["guidance-input"].firstMatch.exists
            ? app.textViews["guidance-input"].firstMatch
            : app.textFields["guidance-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("I want to take the Shinkansen! I'd like a seat with a view of Mt. Fuji.")
        tapID(app, "guidance-submit")
        XCTAssertTrue(element(app, "guidance-summary").waitForExistence(timeout: 8))
    }

    @MainActor
    private func fillBaggage(in app: XCUIApplication, length: String, width: String, height: String) {
        let lengthField = app.textFields["baggage-length"]
        let widthField = app.textFields["baggage-width"]
        let heightField = app.textFields["baggage-height"]
        XCTAssertTrue(lengthField.waitForExistence(timeout: 5))
        lengthField.tap()
        lengthField.typeText(length)
        widthField.tap()
        widthField.typeText(width)
        heightField.tap()
        heightField.typeText(height)
        let done = app.descendants(matching: .any)["keyboard-done"].firstMatch
        if done.waitForExistence(timeout: 2) {
            done.tap()
        }
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func tapID(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = 8) {
        let target = element(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(identifier)")
        if target.isHittable {
            target.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
