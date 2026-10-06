import XCTest

final class BulletGOUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeShowsPrimarySetupAndHasNoTaskCatalog() throws {
        let app = launchApp()

        XCTAssertTrue(element(app, "contextual-home").waitForExistence(timeout: 15))
        XCTAssertTrue(
            element(app, "primary-now").waitForExistence(timeout: 8)
                || element(app, "start-guidance").waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["open-feature-hub"].exists)
        XCTAssertFalse(app.buttons["Features"].exists)
        XCTAssertFalse(element(app, "coming-up-section").exists)
        XCTAssertFalse(app.staticTexts["Coming soon"].exists)
        XCTAssertFalse(app.staticTexts["準備中"].exists)

        tapID(app, "primary-now")
        XCTAssertTrue(element(app, "guidance-sheet").waitForExistence(timeout: 8))
        tapID(app, "guidance-close")
        XCTAssertTrue(element(app, "contextual-home").waitForExistence(timeout: 8))
    }

    @MainActor
    func testEmptyHomeCreatesTrip() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = ["-ui-testing", "-ui-testing-empty"]
        app.launch()

        XCTAssertTrue(element(app, "contextual-home-empty").waitForExistence(timeout: 15))
        tapID(app, "create-trip-button")
        XCTAssertTrue(element(app, "create-trip-sheet").waitForExistence(timeout: 12))
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
        XCTAssertTrue(element(app, "question-choice-shinkansen").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "date-confirm").exists)
        XCTAssertTrue(element(app, "journey-condition-route").waitForExistence(timeout: 3))
        XCTAssertFalse(element(app, "known-section").exists)
        XCTAssertFalse(element(app, "still-needed-section").exists)
        XCTAssertFalse(element(app, "leg-cockpit-readiness").exists)
        XCTAssertFalse(element(app, "start-guidance").exists)
    }

    @MainActor
    func testConfirmingDateStaysOnJourney() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        XCTAssertFalse(element(app, "date-confirm").exists)
        XCTAssertTrue(element(app, "question-choice-shinkansen").waitForExistence(timeout: 8))
        tapID(app, "question-choice-shinkansen")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "guidance-sheet").waitForExistence(timeout: 2))
        XCTAssertFalse(element(app, "contextual-home").exists)
    }

    @MainActor
    func testSetupAnswerAdvancesToNextStep() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        XCTAssertTrue(element(app, "question-choice-shinkansen").waitForExistence(timeout: 8))
        tapID(app, "question-choice-shinkansen")
        XCTAssertTrue(element(app, "question-choice-notBooked").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "leg-setup-current").exists)
        XCTAssertFalse(element(app, "leg-cockpit-summary").exists)
    }

    @MainActor
    func testConditionsStayOnJourneyAfterTransport() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "question-choice-shinkansen")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "question-choice-notBooked").waitForExistence(timeout: 8))
        XCTAssertFalse(element(app, "contextual-home").exists)
        XCTAssertTrue(element(app, "leg-setup").waitForExistence(timeout: 5))
    }

    @MainActor
    func testVerticalSliceFromTalkToBaggageResult() throws {
        let app = launchApp()

        completeTokyoKyotoSetup(in: app)
        tapID(app, "journey-condition-luggage")

        XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 10))
        advanceBaggageGuideIfNeeded(in: app)
        fillBaggage(in: app, length: "80", width: "40", height: "41")
        tapID(app, "baggage-submit")
        XCTAssertTrue(element(app, "baggage-result").waitForExistence(timeout: 8))
        if element(app, "baggage-guide-done").waitForExistence(timeout: 3) {
            tapID(app, "baggage-guide-done")
            XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 10))
            XCTAssertFalse(element(app, "journey-condition-luggage").waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testBookingMethodComingSoonStaysInContext() throws {
        let app = launchApp()

        completeTokyoKyotoSetup(in: app)
        tapID(app, "journey-condition-luggage")
        XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 8))
        advanceBaggageGuideIfNeeded(in: app)
        fillBaggage(in: app, length: "80", width: "40", height: "40")
        tapID(app, "baggage-submit")
        if element(app, "baggage-guide-done").waitForExistence(timeout: 6) {
            tapID(app, "baggage-guide-done")
        }
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 8))
        openHomeTab(in: app)
        XCTAssertTrue(element(app, "contextual-home").waitForExistence(timeout: 8))
        tapID(app, "primary-now")
        if element(app, "task-detail").waitForExistence(timeout: 5) {
            tapID(app, "task-primary-action")
        }
        XCTAssertTrue(element(app, "coming-soon-view").waitForExistence(timeout: 12))
        XCTAssertFalse(element(app, "feature-hub-list").exists)
    }

    @MainActor
    func testBookingMethodListOpensSmartEXAndComingSoon() throws {
        let app = launchApp()

        openTokyoKyoto(in: app)
        tapID(app, "question-choice-shinkansen")
        tapID(app, "question-choice-notBooked")
        tapID(app, "question-choice-no")
        XCTAssertTrue(element(app, "journey-chapter-focus").waitForExistence(timeout: 12))
        tapID(app, "journey-chapter-focus")
        XCTAssertTrue(element(app, "booking-methods").waitForExistence(timeout: 8))
        tapID(app, "booking-method-smartEX")
        XCTAssertTrue(element(app, "booking-method-smartex").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "booking-method-smartex-open").waitForExistence(timeout: 4))
        XCTAssertFalse(element(app, "booking-method-smartex-oversized").exists)
        XCTAssertFalse(element(app, "booking-method-coming-soon").exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "booking-methods").waitForExistence(timeout: 8))
        tapID(app, "booking-method-klook")
        XCTAssertTrue(element(app, "booking-method-coming-soon").waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "journey-chapter-focus").waitForExistence(timeout: 8))
    }

    @MainActor
    func testCockpitLuggageOpensBaggageGuide() throws {
        let app = launchApp()

        completeTokyoKyotoSetup(in: app)
        XCTAssertTrue(element(app, "journey-condition-luggage").waitForExistence(timeout: 8))
        tapID(app, "journey-condition-luggage")
        XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 10))
        advanceBaggageGuideIfNeeded(in: app)
        fillBaggage(in: app, length: "80", width: "40", height: "41")
        tapID(app, "baggage-submit")
        XCTAssertTrue(element(app, "baggage-result").waitForExistence(timeout: 8))
        tapID(app, "baggage-guide-done")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "journey-condition-luggage").waitForExistence(timeout: 3))
    }

    @MainActor
    func testHomePrimaryNowOpensBaggageGuide() throws {
        let app = launchApp()

        completeTokyoKyotoSetup(in: app)
        openHomeTab(in: app)
        XCTAssertTrue(element(app, "contextual-home").waitForExistence(timeout: 8))
        tapID(app, "primary-now")
        XCTAssertTrue(element(app, "baggage-check").waitForExistence(timeout: 10))
        advanceBaggageGuideIfNeeded(in: app)
        fillBaggage(in: app, length: "80", width: "40", height: "41")
        tapID(app, "baggage-submit")
        XCTAssertTrue(element(app, "baggage-result").waitForExistence(timeout: 8))
        tapID(app, "baggage-guide-done")
        XCTAssertTrue(element(app, "contextual-home").waitForExistence(timeout: 10))
    }

    @MainActor
    private func completeTokyoKyotoSetup(in app: XCUIApplication) {
        openTokyoKyoto(in: app)
        tapID(app, "question-choice-shinkansen")
        tapID(app, "question-choice-notBooked")
        tapID(app, "question-choice-yes")
        XCTAssertTrue(element(app, "journey-condition-luggage").waitForExistence(timeout: 12))
    }

    @MainActor
    private func openHomeTab(in app: XCUIApplication) {
        if app.tabBars.buttons["Home"].waitForExistence(timeout: 4) {
            app.tabBars.buttons["Home"].tap()
            return
        }
        if app.tabBars.buttons["ホーム"].waitForExistence(timeout: 2) {
            app.tabBars.buttons["ホーム"].tap()
            return
        }
        tapID(app, "tab-home")
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
        let row = tokyoKyotoRow(in: app)
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<6 where !row.exists {
            if scroll.exists {
                scroll.swipeUp(velocity: .fast)
            } else {
                app.swipeUp(velocity: .fast)
            }
        }
        XCTAssertTrue(row.waitForExistence(timeout: 4), "Missing Tokyo → Kyoto row")
        if !row.isHittable {
            app.swipeUp()
        }
        let hittable = NSPredicate(format: "hittable == true")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: row)], timeout: 5)
        row.tap()
        if !element(app, "trips-quick-context").waitForExistence(timeout: 8) {
            app.swipeUp()
            row.tap()
        }
        XCTAssertTrue(element(app, "trips-quick-context").waitForExistence(timeout: 8), "Quick Context A did not open")
        tapID(app, "trips-quick-context-details")
        XCTAssertTrue(element(app, "leg-detail").waitForExistence(timeout: 12))
    }

    @MainActor
    private func tokyoKyotoRow(in app: XCUIApplication) -> XCUIElement {
        let byID = element(app, "timeline-leg-A1E0B001-0000-4000-8000-000000000011")
        if byID.exists {
            return byID
        }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Tokyo' AND label CONTAINS 'Kyoto'"))
            .firstMatch
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
