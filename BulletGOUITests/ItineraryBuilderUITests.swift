import XCTest

final class ItineraryBuilderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStoreCreatesTripAddsTransportAndTalks() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = ["-ui-testing", "-ui-testing-empty"]
        app.launch()

        XCTAssertTrue(
            element(app, "contextual-home-empty").waitForExistence(timeout: 15)
                || element(app, "trip-timeline-empty").waitForExistence(timeout: 5)
                || app.buttons["Create trip"].waitForExistence(timeout: 5)
        )
        let create = element(app, "create-trip-button")
        if !create.waitForExistence(timeout: 8) {
            XCTAssertTrue(app.buttons["Create trip"].waitForExistence(timeout: 8), "Missing create trip")
            app.buttons["Create trip"].tap()
        } else {
            tapID(app, "create-trip-button")
        }
        XCTAssertTrue(
            element(app, "create-trip-sheet").waitForExistence(timeout: 12)
                || app.textFields["create-trip-name"].waitForExistence(timeout: 8),
            "Create trip sheet did not appear"
        )
        let name = app.textFields["create-trip-name"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        focusAndType(name, " Japan")
        dismissKeyboard(in: app)
        tapID(app, "create-trip-save")
        openTripsTab(in: app)
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))

        tapID(app, "add-itinerary-button")
        XCTAssertTrue(element(app, "add-itinerary-sheet").waitForExistence(timeout: 5))
        let origin = app.textFields["add-itinerary-origin"].firstMatch
        let destination = app.textFields["add-itinerary-destination"].firstMatch
        XCTAssertTrue(origin.waitForExistence(timeout: 5))
        focusAndType(origin, "Tokyo")
        focusAndType(destination, "Osaka")
        dismissKeyboard(in: app)
        tapID(app, "add-itinerary-save")
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))

        tapID(app, "talk-about-trip")
        XCTAssertTrue(element(app, "itinerary-talk-sheet").waitForExistence(timeout: 5))
        let input = app.textFields["itinerary-talk-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        focusAndType(input, "October 2 morning, Tokyo to Kyoto by Shinkansen. Large suitcase.")
        dismissKeyboard(in: app)
        tapID(app, "itinerary-talk-submit")
        XCTAssertTrue(element(app, "itinerary-draft-review").waitForExistence(timeout: 8))
        tapID(app, "itinerary-draft-confirm")
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))
    }

    @MainActor
    private func openTripsTab(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Trips"]
        if tab.waitForExistence(timeout: 8) {
            tab.tap()
            return
        }
        tapID(app, "tab-trips")
    }

    @MainActor
    private func focusAndType(_ field: XCUIElement, _ text: String) {
        field.tap()
        Thread.sleep(forTimeInterval: 0.35)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.2)
        field.typeText(text)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.descendants(matching: .any)["keyboard-done"].firstMatch
        if done.waitForExistence(timeout: 1) {
            done.tap()
            return
        }
        let ret = app.keyboards.buttons["return"].firstMatch
        if ret.exists {
            ret.tap()
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
