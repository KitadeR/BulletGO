import XCTest

final class ItineraryBuilderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStoreCreatesTripAndAddsTravel() throws {
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

        addTravelViaFAB(in: app, origin: "Tokyo", destination: "Osaka")
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Tokyo'")).firstMatch
                .waitForExistence(timeout: 8)
        )
        XCTAssertFalse(element(app, "add-itinerary-button").exists)
        XCTAssertFalse(element(app, "talk-about-trip").exists)
    }

    @MainActor
    func testDateSelectorJumpShowsEmptyDayAndAddsWithDateContext() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 15)
                || element(app, "contextual-home").waitForExistence(timeout: 8)
                || element(app, "tab-home").waitForExistence(timeout: 5),
            "App did not show the main tabs"
        )
        openTripsTab(in: app)
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "trips-date-selector").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "timeline-leg-A1E0B001-0000-4000-8000-000000000011").waitForExistence(timeout: 8))

        let oct3 = element(app, "trips-date-2026-10-3")
        if !oct3.waitForExistence(timeout: 2) || !oct3.isHittable {
            element(app, "trips-date-selector").swipeLeft()
        }
        tapID(app, "trips-date-2026-10-3")
        XCTAssertTrue(element(app, "trips-day-add-2026-10-3").waitForExistence(timeout: 8), "Empty Oct 3 add control missing")
        XCTAssertTrue(
            element(app, "trips-empty-day").waitForExistence(timeout: 4)
                || app.staticTexts["Nothing planned yet"].exists
                || app.staticTexts["まだ予定はありません"].exists
                || element(app, "itinerary-day-2026-10-3").exists,
            "Empty Oct 3 day did not appear"
        )

        addTravelViaFAB(in: app, origin: "Nara", destination: "Osaka")
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "itinerary-day-2026-10-3").waitForExistence(timeout: 8))
        XCTAssertFalse(element(app, "trips-empty-day").waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Nara'")).firstMatch
                .waitForExistence(timeout: 8)
        )
        XCTAssertFalse(element(app, "add-itinerary-button").exists)
        XCTAssertFalse(element(app, "talk-about-trip").exists)
    }

    @MainActor
    private func addTravelViaFAB(in app: XCUIApplication, origin: String, destination: String) {
        tapID(app, "trips-v2-floating-add")
        let travel = element(app, "trips-v2-add-leg")
        if travel.waitForExistence(timeout: 3) {
            tapID(app, "trips-v2-add-leg")
        } else if app.buttons["Travel"].waitForExistence(timeout: 3) {
            app.buttons["Travel"].tap()
        } else {
            XCTFail("Missing Guided Add Travel action")
        }

        XCTAssertTrue(element(app, "guided-add-sheet").waitForExistence(timeout: 8))
        let originField = app.textFields["guided-add-origin"].firstMatch
        XCTAssertTrue(originField.waitForExistence(timeout: 5))
        focusAndType(originField, origin)
        dismissKeyboard(in: app)
        tapID(app, "guided-add-continue")

        let destinationField = app.textFields["guided-add-destination"].firstMatch
        XCTAssertTrue(destinationField.waitForExistence(timeout: 5))
        focusAndType(destinationField, destination)
        dismissKeyboard(in: app)
        tapID(app, "guided-add-continue")

        if element(app, "guided-add-skip").waitForExistence(timeout: 3) {
            tapID(app, "guided-add-skip")
        } else {
            tapID(app, "guided-add-continue")
        }

        if element(app, "guided-add-continue").waitForExistence(timeout: 3) {
            tapID(app, "guided-add-continue")
        }
        tapID(app, "guided-add-save")
    }

    @MainActor
    private func openTripsTab(in app: XCUIApplication) {
        if app.tabBars.buttons["Trips"].waitForExistence(timeout: 8) {
            app.tabBars.buttons["Trips"].tap()
            return
        }
        if app.tabBars.buttons["旅程"].waitForExistence(timeout: 2) {
            app.tabBars.buttons["旅程"].tap()
            return
        }
        tapID(app, "tab-trips", timeout: 15)
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
