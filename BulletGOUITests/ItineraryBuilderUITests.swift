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
    func testEmptyStoreCreatesTripAndAddsSearchedActivity() throws {
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

        chooseGuidedAddKind(
            in: app,
            menuControlID: "trips-v2-floating-add",
            identifier: "trips-v2-add-activity",
            labels: ["Place or activity", "場所", "Activity"],
            failure: "Missing Guided Add Activity action"
        )

        XCTAssertTrue(element(app, "guided-add-sheet").waitForExistence(timeout: 8))
        let placeField = app.textFields["guided-add-place"].firstMatch
        XCTAssertTrue(placeField.waitForExistence(timeout: 5))
        focusAndType(placeField, "Kinkaku")
        let result = element(app, "place-search-result-kinkaku")
        XCTAssertTrue(result.waitForExistence(timeout: 8), "Fake place result did not appear")
        if result.isHittable {
            result.tap()
        } else {
            result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(element(app, "place-search-selected").waitForExistence(timeout: 5))
        dismissKeyboard(in: app)
        tapID(app, "guided-add-continue")
        tapID(app, "guided-add-continue")
        if element(app, "guided-add-skip").waitForExistence(timeout: 3) {
            tapID(app, "guided-add-skip")
        } else {
            tapID(app, "guided-add-continue")
        }
        tapID(app, "guided-add-save")

        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Kinkaku-ji'")).firstMatch
                .waitForExistence(timeout: 8)
        )
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
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 20))
        XCTAssertTrue(element(app, "trips-date-selector").waitForExistence(timeout: 8))
        XCTAssertTrue(element(app, "timeline-leg-A1E0B001-0000-4000-8000-000000000011").waitForExistence(timeout: 8))

        let oct3 = element(app, "trips-date-2026-10-3")
        if !oct3.waitForExistence(timeout: 2) || !oct3.isHittable {
            element(app, "trips-date-selector").swipeLeft()
        }
        tapID(app, "trips-date-2026-10-3")
        XCTAssertTrue(element(app, "trips-day-add-2026-10-3").waitForExistence(timeout: 8), "Empty Oct 3 add control missing")
        XCTAssertTrue(
            element(app, "trips-empty-day-2026-10-3").waitForExistence(timeout: 4)
                || app.staticTexts["Nothing planned yet"].exists
                || app.staticTexts["まだ予定はありません"].exists
                || element(app, "itinerary-day-2026-10-3").exists,
            "Empty Oct 3 day did not appear"
        )

        addTravelViaFAB(
            in: app,
            origin: "Nara",
            destination: "Osaka",
            menuControlID: "trips-day-add-2026-10-3"
        )
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8))
        if !element(app, "itinerary-day-2026-10-3").waitForExistence(timeout: 3) {
            tapID(app, "trips-date-2026-10-3")
        }
        XCTAssertTrue(
            element(app, "itinerary-day-2026-10-3").waitForExistence(timeout: 8)
                || element(app, "trips-day-add-2026-10-3").waitForExistence(timeout: 4),
            "Oct 3 day did not stay visible after adding"
        )
        XCTAssertFalse(element(app, "trips-empty-day-2026-10-3").waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS 'Nara' OR label CONTAINS 'Osaka'")
            ).firstMatch.waitForExistence(timeout: 8),
            "Added travel did not appear on Oct 3"
        )
        XCTAssertFalse(element(app, "add-itinerary-button").exists)
        XCTAssertFalse(element(app, "talk-about-trip").exists)
    }

    @MainActor
    private func addTravelViaFAB(
        in app: XCUIApplication,
        origin: String,
        destination: String,
        menuControlID: String = "trips-v2-floating-add"
    ) {
        chooseGuidedAddKind(
            in: app,
            menuControlID: menuControlID,
            identifier: "trips-v2-add-leg",
            labels: ["Travel", "移動"],
            failure: "Missing Guided Add Travel action"
        )

        XCTAssertTrue(
            element(app, "guided-add-sheet").waitForExistence(timeout: 12)
                || app.textFields["guided-add-origin"].firstMatch.waitForExistence(timeout: 8)
                || app.staticTexts["移動を追加"].waitForExistence(timeout: 3),
            "Travel sheet missing"
        )
        fillTravelPlace(
            in: app,
            fieldID: "guided-add-origin",
            selectedID: "guided-add-origin-selected",
            query: origin
        )
        tapID(app, "guided-add-origin-selected")
        XCTAssertTrue(
            app.textFields["guided-add-origin"].firstMatch.waitForExistence(timeout: 8)
                || element(app, "guided-add-origin").waitForExistence(timeout: 3),
            "Origin field did not re-expand"
        )
        fillTravelPlace(
            in: app,
            fieldID: "guided-add-origin",
            selectedID: "guided-add-origin-selected",
            query: origin
        )
        fillTravelPlace(
            in: app,
            fieldID: "guided-add-destination",
            selectedID: "guided-add-destination-selected",
            query: destination
        )
        tapEnabledID(app, "guided-add-continue")
        XCTAssertTrue(element(app, "guided-add-mode-shinkansen").waitForExistence(timeout: 8), "How step missing")
        tapID(app, "guided-add-mode-shinkansen")
        tapEnabledID(app, "guided-add-continue")
        chooseTravelDateIfNeeded(in: app)
        reexpandAndReselectTravelDate(in: app)
        confirmTravelClock(in: app)
        tapEnabledID(app, "guided-add-continue")
        XCTAssertTrue(element(app, "guided-add-review-from").waitForExistence(timeout: 8), "Review missing")
        tapID(app, "guided-add-review-from")
        XCTAssertTrue(
            element(app, "guided-add-origin-selected").waitForExistence(timeout: 5)
                || app.textFields["guided-add-origin"].firstMatch.waitForExistence(timeout: 5),
            "Review edit did not return to places"
        )
        tapEnabledID(app, "guided-add-continue")
        if element(app, "guided-add-mode-shinkansen").waitForExistence(timeout: 5) {
            tapEnabledID(app, "guided-add-continue")
        }
        if element(app, "guided-add-continue").waitForExistence(timeout: 3) {
            tapEnabledID(app, "guided-add-continue")
        }
        tapID(app, "guided-add-save")
        XCTAssertTrue(element(app, "trip-timeline").waitForExistence(timeout: 8), "Timeline did not return after adding travel")
    }

    @MainActor
    private func chooseTravelDateIfNeeded(in app: XCUIApplication) {
        let dateCells = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier MATCHES %@", "guided-add-date-[0-9]+-[0-9]+-[0-9]+")
        )
        if dateCells.firstMatch.waitForExistence(timeout: 2) {
            tapEnabledDateCell(dateCells)
            return
        }
        let continueButton = element(app, "guided-add-continue")
        if continueButton.waitForExistence(timeout: 2), continueButton.isEnabled {
            return
        }
        XCTAssertTrue(dateCells.firstMatch.waitForExistence(timeout: 5), "Date grid missing")
        tapEnabledDateCell(dateCells)
    }

    @MainActor
    private func reexpandAndReselectTravelDate(in app: XCUIApplication) {
        let collapsedDate = element(app, "guided-add-date-selected")
        guard collapsedDate.waitForExistence(timeout: 3) else { return }
        if !collapsedDate.isHittable {
            app.swipeDown()
        }
        tapID(app, "guided-add-date-selected")
        guard element(app, "guided-add-date").waitForExistence(timeout: 5) else { return }
        let dateCells = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier MATCHES %@", "guided-add-date-[0-9]+-[0-9]+-[0-9]+")
        )
        guard dateCells.firstMatch.waitForExistence(timeout: 3) else { return }
        tapEnabledDateCell(dateCells)
        _ = element(app, "guided-add-date-selected").waitForExistence(timeout: 5)
    }

    @MainActor
    private func confirmTravelClock(in app: XCUIApplication) {
        if !element(app, "guided-add-time-departure").waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        tapID(app, "guided-add-time-departure")
        if !element(app, "guided-add-clock").waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(element(app, "guided-add-clock").waitForExistence(timeout: 5), "Clock missing after departure")
        let continueButton = element(app, "guided-add-continue")
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        XCTAssertFalse(continueButton.isEnabled, "Clock must be interacted with before continue")
        let hourNext = element(app, "guided-add-clock-hour-next")
        if hourNext.waitForExistence(timeout: 3) {
            if hourNext.isHittable {
                hourNext.tap()
            } else {
                hourNext.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            let hour = element(app, "guided-add-clock-hour")
            XCTAssertTrue(hour.waitForExistence(timeout: 5), "Clock hour increment missing")
            hour.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        }
        XCTAssertTrue(element(app, "guided-add-continue").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "guided-add-continue").isEnabled, "Continue stayed disabled after clock")
    }

    @MainActor
    private func tapEnabledDateCell(_ cells: XCUIElementQuery) {
        let limit = min(cells.count, 21)
        for index in 0..<limit {
            let cell = cells.element(boundBy: index)
            guard cell.exists, cell.isEnabled else { continue }
            tapDateCell(cell)
            return
        }
        XCTFail("No enabled date cell")
    }

    @MainActor
    private func tapDateCell(_ cell: XCUIElement) {
        if cell.isHittable {
            cell.tap()
        } else {
            cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func fillTravelPlace(
        in app: XCUIApplication,
        fieldID: String,
        selectedID: String,
        query: String
    ) {
        if element(app, selectedID).waitForExistence(timeout: 1) {
            return
        }
        let collapsed = element(app, fieldID)
        let field = app.textFields[fieldID].firstMatch
        if !field.waitForExistence(timeout: 2), collapsed.waitForExistence(timeout: 2) {
            tapID(app, fieldID)
        }
        XCTAssertTrue(field.waitForExistence(timeout: 8), "\(fieldID) field missing")
        let current = (field.value as? String) ?? ""
        if !current.localizedCaseInsensitiveContains(query) {
            focusAndType(field, query)
        } else {
            field.tap()
        }
        tapPlaceResult(in: app, matching: query)
        XCTAssertTrue(element(app, selectedID).waitForExistence(timeout: 8), "\(selectedID) missing after candidate tap")
    }

    @MainActor
    private func tapPlaceResult(in app: XCUIApplication, matching query: String) {
        let identifier = placeResultID(for: query)
        let result = element(app, identifier)
        XCTAssertTrue(result.waitForExistence(timeout: 8), "Fake place result \(identifier) did not appear")
        if !result.isHittable {
            app.swipeUp()
        }
        if result.isHittable {
            result.tap()
        } else {
            result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func placeResultID(for query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.contains("tokyo") { return "place-search-result-tokyo" }
        if trimmed.contains("osaka") { return "place-search-result-osaka" }
        if trimmed.contains("nara") { return "place-search-result-nara" }
        if trimmed.contains("kinkaku") { return "place-search-result-kinkaku" }
        return "place-search-result-\(trimmed)"
    }

    @MainActor
    private func chooseGuidedAddKind(
        in app: XCUIApplication,
        menuControlID: String,
        identifier: String,
        labels: [String],
        failure: String
    ) {
        tapID(app, menuControlID)
        Thread.sleep(forTimeInterval: 0.4)
        if element(app, identifier).waitForExistence(timeout: 5) {
            tapID(app, identifier)
            return
        }
        for label in labels {
            let match = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@ OR label CONTAINS %@", label, label)
            ).firstMatch
            if match.waitForExistence(timeout: 2) {
                if match.isHittable {
                    match.tap()
                } else {
                    match.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return
            }
        }
        XCTFail(failure)
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
    private func tapEnabledID(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = 8) {
        dismissKeyboard(in: app)
        let target = element(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(identifier)")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !target.isEnabled {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(target.isEnabled, "\(identifier) stayed disabled")
        tapID(app, identifier, timeout: 2)
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
