import XCTest

final class BulletGOUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeHasNoFeatureCatalogAndOpensJourney() throws {
        let app = launchApp()

        XCTAssertTrue(
            element(app, "contextual-home").waitForExistence(timeout: 15)
                || element(app, "tab-home").waitForExistence(timeout: 5)
                || app.tabBars.buttons["Home"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["open-feature-hub"].exists)
        XCTAssertFalse(app.buttons["Features"].exists)

        openTokyoKyoto(in: app)
        XCTAssertTrue(element(app, "leg-setup").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "leg-setup-current").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "date-confirm").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "known-section").exists)
        XCTAssertFalse(element(app, "still-needed-section").exists)
        XCTAssertFalse(element(app, "leg-cockpit-readiness").exists)
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
        XCTAssertTrue(element(app, "leg-setup").waitForExistence(timeout: 5))
    }

    @MainActor
    func testSetupAnswerAdvancesToNextStep() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        XCTAssertTrue(element(app, "date-confirm").waitForExistence(timeout: 8))
        tapID(app, "date-confirm")
        XCTAssertTrue(element(app, "question-choice-shinkansen").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "leg-setup-current").exists)
        XCTAssertFalse(element(app, "leg-cockpit-summary").exists)
    }

    @MainActor
    func testTalkReturnsToJourneyInsteadOfHome() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "start-guidance")
        enterReferenceTalk(in: app)
        tapID(app, "guidance-continue")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 8))
        XCTAssertFalse(element(app, "guidance-sheet").waitForExistence(timeout: 2))
        XCTAssertFalse(element(app, "contextual-home").exists)
        XCTAssertTrue(element(app, "leg-setup").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "date-confirm").waitForExistence(timeout: 8))
    }

    @MainActor
    func testVerticalSliceFromTalkToBaggageResult() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "start-guidance")
        enterReferenceTalk(in: app)
        tapID(app, "guidance-continue")
        XCTAssertTrue(element(app, "date-confirm").waitForExistence(timeout: 10))
        tapID(app, "date-confirm")
        tapID(app, "question-choice-notBooked")
        tapID(app, "question-choice-yes")

        XCTAssertTrue(element(app, "leg-cockpit-summary").waitForExistence(timeout: 12))
        let capture = element(app, "now-task-capture_dimensions")
        XCTAssertTrue(capture.waitForExistence(timeout: 8), "Missing capture dimensions")
        if !capture.isHittable {
            app.swipeUp()
        }
        capture.tap()

        XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 10))
        advanceBaggageGuideIfNeeded(in: app)
        fillBaggage(in: app, length: "80", width: "40", height: "41")
        tapID(app, "baggage-submit")
        XCTAssertTrue(element(app, "baggage-result").waitForExistence(timeout: 8))
        if element(app, "baggage-guide-done").waitForExistence(timeout: 3) {
            tapID(app, "baggage-guide-done")
            XCTAssertTrue(
                element(app, "leg-detail").waitForExistence(timeout: 10)
                    || element(app, "contextual-home").waitForExistence(timeout: 5)
            )
            XCTAssertFalse(element(app, "now-task-capture_dimensions").waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testBookingMethodComingSoonStaysInContext() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "start-guidance")
        enterReferenceTalk(in: app)
        tapID(app, "guidance-continue")
        XCTAssertTrue(element(app, "date-confirm").waitForExistence(timeout: 10))
        tapID(app, "date-confirm")
        tapID(app, "question-choice-notBooked")
        tapID(app, "question-choice-yes")
        XCTAssertTrue(element(app, "leg-cockpit-whats-next").waitForExistence(timeout: 12))
        let capture = element(app, "now-task-capture_dimensions")
        if capture.waitForExistence(timeout: 6) {
            capture.tap()
            XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 8))
            advanceBaggageGuideIfNeeded(in: app)
            fillBaggage(in: app, length: "80", width: "40", height: "40")
            tapID(app, "baggage-submit")
            if element(app, "baggage-guide-done").waitForExistence(timeout: 6) {
                tapID(app, "baggage-guide-done")
            } else {
                tapID(app, "tab-home", timeout: 3)
            }
        }
        if !element(app, "now-task-select_booking_method").waitForExistence(timeout: 4) {
            tapID(app, "tab-home", timeout: 3)
        }
        tapID(app, "now-task-select_booking_method", timeout: 10)
        XCTAssertTrue(element(app, "task-detail").waitForExistence(timeout: 5))
        tapID(app, "task-primary-action")
        XCTAssertTrue(element(app, "coming-soon-view").waitForExistence(timeout: 12))
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
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 15)
                || element(app, "contextual-home").waitForExistence(timeout: 8)
                || element(app, "contextual-home-empty").waitForExistence(timeout: 5)
                || element(app, "tab-home").waitForExistence(timeout: 5),
            "App did not show the main tabs"
        )
        return app
    }

    @MainActor
    private func openTokyoKyoto(in app: XCUIApplication) {
        openTripsTab(in: app)
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 15))
        let row = element(app, "timeline-leg-A1E0B001-0000-4000-8000-000000000011")
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Missing Tokyo → Kyoto row")
        if !row.isHittable {
            app.swipeUp()
        }
        let hittable = NSPredicate(format: "hittable == true")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: row)], timeout: 5)
        row.tap()
        if !element(app, "leg-detail").waitForExistence(timeout: 8) {
            app.swipeUp()
            row.tap()
        }
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 12))
    }

    @MainActor
    private func openTripsTab(in app: XCUIApplication) {
        if app.tabBars.buttons["Trips"].waitForExistence(timeout: 4) {
            app.tabBars.buttons["Trips"].tap()
            return
        }
        if app.tabBars.buttons["旅程"].waitForExistence(timeout: 2) {
            app.tabBars.buttons["旅程"].tap()
            return
        }
        tapID(app, "tab-trips")
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
    private func advanceBaggageGuideIfNeeded(in app: XCUIApplication) {
        for _ in 0..<4 {
            let next = element(app, "baggage-guide-next")
            guard next.waitForExistence(timeout: 1) else { return }
            if next.isHittable {
                next.tap()
            } else {
                next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
    }

    @MainActor
    private func fillBaggage(in app: XCUIApplication, length: String, width: String, height: String) {
        let lengthField = app.textFields["baggage-length"]
        let widthField = app.textFields["baggage-width"]
        let heightField = app.textFields["baggage-height"]
        XCTAssertTrue(lengthField.waitForExistence(timeout: 5))
        typeInto(app, lengthField, length)
        typeInto(app, widthField, width)
        typeInto(app, heightField, height)
        let done = app.descendants(matching: .any)["keyboard-done"].firstMatch
        if done.waitForExistence(timeout: 2) {
            done.tap()
        }
    }

    @MainActor
    private func typeInto(_ app: XCUIApplication, _ field: XCUIElement, _ text: String) {
        field.tap()
        Thread.sleep(forTimeInterval: 0.35)
        app.typeText(text)
        let done = app.descendants(matching: .any)["keyboard-done"].firstMatch
        if done.waitForExistence(timeout: 1) {
            done.tap()
            Thread.sleep(forTimeInterval: 0.2)
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
