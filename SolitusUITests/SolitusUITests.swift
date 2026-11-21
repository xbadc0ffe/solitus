import XCTest

/// Drives the app in the simulator: the gestures on a card, the form, the
/// tabs. Run with `xcodebuild test -scheme SolitusUITests`.
///
/// Every test starts from an empty in-memory store seeded with the ten
/// sample tasks (Walk 0/1, Medication 1/3, Tobacco clear, and so on).
final class SolitusUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-seedSampleData"]
        app.launch()
    }

    private func card(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "card-" + name).firstMatch
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func openTab(_ name: String) {
        app.buttons[name].firstMatch.tap()
    }

    // MARK: Track

    func testHoldingACardLogsOne() {
        let walk = card("Walk")
        XCTAssertTrue(walk.waitForExistence(timeout: 10))
        XCTAssertTrue(walk.label.contains("0/1"), walk.label)
        walk.press(forDuration: 1.0)
        XCTAssertTrue(waitForLabel(walk, containing: "Done"), walk.label)
        // Lifting after the hold must not also count as a tap.
        XCTAssertFalse(waitForLabel(walk, containing: "average", timeout: 1.5), walk.label)
    }

    func testAShortPressDoesNotLog() {
        let walk = card("Walk")
        XCTAssertTrue(walk.waitForExistence(timeout: 10))
        walk.press(forDuration: 0.3)
        XCTAssertFalse(waitForLabel(walk, containing: "Done", timeout: 2), walk.label)
        // Nothing was logged: the details show no Undo button.
        walk.doubleTap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5), "details did not open")
        XCTAssertFalse(app.buttons["Undo last"].exists)
    }

    func testHoldingAMultiCountCardAddsOneStep() {
        let medication = card("Medication")
        XCTAssertTrue(medication.waitForExistence(timeout: 10))
        XCTAssertTrue(medication.label.contains("1/3"), medication.label)
        medication.press(forDuration: 1.0)
        XCTAssertTrue(waitForLabel(medication, containing: "2/3"), medication.label)
    }

    func testHoldingAnAvoidCardRecordsAnOccurrence() {
        let tobacco = card("Tobacco")
        XCTAssertTrue(tobacco.waitForExistence(timeout: 10))
        XCTAssertTrue(tobacco.label.contains("0 clear today"), tobacco.label)
        tobacco.press(forDuration: 1.0)
        XCTAssertTrue(waitForLabel(tobacco, containing: "1 today"), tobacco.label)
    }

    func testTappingACardCyclesTheQuickStat() {
        let read = card("Read")
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()
        XCTAssertTrue(waitForLabel(read, containing: "30-day average"), read.label)
        read.tap()
        XCTAssertTrue(waitForLabel(read, containing: "90-day average"), read.label)
    }

    /// A drag that starts on a card must scroll the page, not start a hold.
    /// (Ten cards fit on Track without scrolling, so this uses the long
    /// Task details page, whose top card has the same hold gesture.)
    func testAPageScrollsWhenDraggedFromACard() {
        card("Medication").doubleTap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5), "details did not open")
        let tracker = card("Medication")
        let before = tracker.frame.minY
        let start = tracker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -260)))
        XCTAssertFalse(tracker.exists && tracker.frame.minY > before - 60, "the page did not scroll")

        // Scrolling back, the count is unchanged: the drag logged nothing.
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(waitForLabel(card("Medication"), containing: "1/3"), card("Medication").label)
    }

    func testDoubleTapOpensDetailsWithUndoAndEdit() {
        let medication = card("Medication")
        XCTAssertTrue(medication.waitForExistence(timeout: 10))
        medication.doubleTap()

        let undo = app.buttons["Undo last"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "details did not open")
        XCTAssertTrue(app.staticTexts["November 2026"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS '2026'")).count > 0)

        // Medication starts at 1 today; undoing it hides the button.
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5))

        // Holding the tracker card logs again.
        let tracker = card("Medication")
        tracker.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Undo last"].waitForExistence(timeout: 5))

        app.buttons["Edit"].tap()
        XCTAssertTrue(app.staticTexts["Edit task"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Edit task"].waitForNonExistence(timeout: 5))
    }

    // MARK: Tasks and the form

    func testAddingATaskShowsItOnTasksAndTrack() {
        openTab("Tasks")
        app.buttons["Add a task"].tap()
        XCTAssertTrue(app.staticTexts["New task"].waitForExistence(timeout: 5))

        let name = app.textFields["Task name"]
        name.tap()
        name.typeText("Floss")
        app.buttons["Weekly"].tap()
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["New task"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Floss"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Weekly, once"].exists)

        openTab("Track")
        XCTAssertTrue(card("Floss").waitForExistence(timeout: 5))
    }

    func testSaveIsDisabledWithoutAName() {
        openTab("Tasks")
        app.buttons["Add a task"].tap()
        XCTAssertTrue(app.staticTexts["New task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
    }

    func testSwitchingTypeToAvoidChangesTheGoal() {
        openTab("Tasks")
        app.buttons["Add a task"].tap()
        XCTAssertTrue(app.buttons["Exactly"].waitForExistence(timeout: 5))
        app.buttons["Avoid"].tap()
        XCTAssertTrue(app.buttons["At most"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Exactly"].exists)
        XCTAssertTrue(app.staticTexts["Allowed per day"].exists)
    }

    func testDeletingATaskRemovesIt() {
        openTab("Tasks")
        let row = app.staticTexts["Read"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["Edit task"].waitForExistence(timeout: 5))

        let delete = app.buttons["Delete"]
        for _ in 0..<6 where !delete.isHittable {
            app.swipeUp()
        }
        delete.tap()
        // The confirmation.
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Delete'")).element(boundBy: app.buttons.matching(NSPredicate(format: "label == 'Delete'")).count - 1)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Edit task"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    func testDraggingAHandleReordersTheList() {
        openTab("Tasks")
        let drinks = app.staticTexts["Drinks"]
        let medication = app.staticTexts["Medication"]
        XCTAssertTrue(drinks.waitForExistence(timeout: 5))
        XCTAssertLessThan(drinks.frame.minY, medication.frame.minY)

        let handle = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Reorder Drinks'")).firstMatch
        XCTAssertTrue(handle.exists)
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 75)))

        XCTAssertGreaterThan(drinks.frame.minY, medication.frame.minY, "Drinks did not move below Medication")

        // The new order is kept: it is still there after leaving the tab.
        openTab("Settings")
        openTab("Tasks")
        XCTAssertTrue(drinks.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(drinks.frame.minY, medication.frame.minY)
    }

    func testPreferredTimesCanBeOpenedAndCleared() {
        openTab("Tasks")
        app.staticTexts["Medication"].tap()
        XCTAssertTrue(app.staticTexts["Preferred times"].waitForExistence(timeout: 5))
        // The sample task has slots at 8:00, 14:00 and 21:00.
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '8:00'")).firstMatch
        XCTAssertTrue(chip.exists)
        chip.tap()
        let clear = app.buttons["Clear this one"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
    }

    // MARK: First run

    func testFirstRunIsEmptyAndSampleTasksCanBeLoaded() {
        app.terminate()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nothing to track yet"].waitForExistence(timeout: 10))
        openTab("Trends")
        XCTAssertTrue(app.staticTexts["Nothing to chart yet"].waitForExistence(timeout: 5))
        openTab("Tasks")
        XCTAssertTrue(app.staticTexts["No tasks yet"].waitForExistence(timeout: 5))

        openTab("Settings")
        let load = app.buttons["Load sample tasks"]
        for _ in 0..<6 where !load.isHittable {
            app.swipeUp()
        }
        load.tap()
        XCTAssertTrue(load.waitForNonExistence(timeout: 5))

        openTab("Track")
        XCTAssertTrue(card("Walk").waitForExistence(timeout: 5))
    }

    // MARK: Trends and Settings

    func testTrendsOpensTheGraphSheetAndATask() {
        openTab("Trends")
        XCTAssertTrue(app.staticTexts["Trends"].waitForExistence(timeout: 5))
        app.buttons["90 days"].firstMatch.tap()

        let graph = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Running average over'")).firstMatch
        XCTAssertTrue(graph.waitForExistence(timeout: 5))
        graph.tap()
        XCTAssertTrue(app.staticTexts["Running average"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add a task"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Running average"].waitForNonExistence(timeout: 5))
    }

    func testSettingsShowsItsGroupsAndTheSwitchesTurn() {
        openTab("Settings")
        let toggle = app.buttons["Emphasise streaks"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "On")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "Off")
        XCTAssertTrue(app.staticTexts["Week starts on"].exists)
    }
}
