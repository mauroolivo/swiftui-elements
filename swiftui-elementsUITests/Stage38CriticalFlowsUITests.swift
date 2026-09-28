import XCTest

final class Stage38CriticalFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    private func candidates(for identifier: String) -> [XCUIElement] {
        [
            app.buttons[identifier],
            app.otherElements[identifier],
            app.staticTexts[identifier],
            app.cells[identifier],
            app.images[identifier],
            app.descendants(matching: .any)[identifier].firstMatch
        ]
    }

    private func firstExistingCandidate(for identifier: String) -> XCUIElement? {
        candidates(for: identifier).first(where: { $0.exists })
    }

    private func debugTabLookup(_ identifier: String) {
        let button = app.buttons[identifier]
        let other = app.otherElements[identifier]
        let text = app.staticTexts[identifier]
        let cell = app.cells[identifier]

        XCTContext.runActivity(named: "Debug tab lookup \(identifier)") { _ in
            print("[UITest] \(identifier) button.exists=\(button.exists) hittable=\(button.isHittable)")
            print("[UITest] \(identifier) other.exists=\(other.exists) hittable=\(other.isHittable)")
            print("[UITest] \(identifier) text.exists=\(text.exists) hittable=\(text.isHittable)")
            print("[UITest] \(identifier) cell.exists=\(cell.exists) hittable=\(cell.isHittable)")
            print("[UITest] stage38.tabBar exists=\(app.otherElements["stage38.tabBar"].exists)")
            print("[UITest] Stage38 list tables=\(app.tables.count) collections=\(app.collectionViews.count) scrollViews=\(app.scrollViews.count)")
            print(app.debugDescription)
        }
    }

    private func stageListContainer() -> XCUIElement {
        if app.tables.firstMatch.exists {
            return app.tables.firstMatch
        }
        if app.collectionViews.firstMatch.exists {
            return app.collectionViews.firstMatch
        }
        return app.scrollViews.firstMatch
    }

    private func tapElement(_ identifier: String, scrollInList: Bool = true) {
        if let element = firstExistingCandidate(for: identifier), element.isHittable {
            element.tap()
            return
        }

        guard scrollInList else {
            if let element = firstExistingCandidate(for: identifier) {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                return
            }
            XCTFail("Could not find element \(identifier)")
            return
        }

        let list = stageListContainer()
        XCTAssertTrue(list.waitForExistence(timeout: 1.0), "Expected the Stage 38 list to exist")

        // SwiftUI List lazily realizes rows; swipe to force creation of offscreen cells.
        for _ in 0..<8 {
            list.swipeUp()
            if let element = firstExistingCandidate(for: identifier), element.isHittable {
                element.tap()
                return
            }
        }

        for _ in 0..<4 {
            list.swipeDown()
            if let element = firstExistingCandidate(for: identifier), element.isHittable {
                element.tap()
                return
            }
        }

        if let element = firstExistingCandidate(for: identifier) {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }

        debugTabLookup(identifier)
        XCTFail("Could not find element \(identifier)")
    }

    private func waitForTabSelected(_ identifier: String, timeout: TimeInterval = 1.5) -> Bool {
        let selectedPredicate = NSPredicate(format: "value == %@", "selected")
        let expectation = XCTNSPredicateExpectation(predicate: selectedPredicate, object: app.buttons[identifier])
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func isTabSelected(_ identifier: String) -> Bool {
        app.buttons.matching(identifier: identifier).allElementsBoundByIndex.contains {
            ($0.value as? String) == "selected"
        }
    }

    private func firstHittableTabButton(_ identifier: String) -> XCUIElement? {
        let matches = app.buttons.matching(identifier: identifier).allElementsBoundByIndex
        return matches.first(where: { $0.isHittable }) ?? matches.first
    }

    private func tapTab(_ identifierSuffix: String) {
        let identifier = "stage38.tab.\(identifierSuffix)"

        for _ in 0..<4 {
            if isTabSelected(identifier) {
                return
            }

            if let button = firstHittableTabButton(identifier) {
                button.tap()
            } else {
                tapElement(identifier)
            }

            if waitForTabSelected(identifier, timeout: 0.8) || isTabSelected(identifier) {
                return
            }
        }

        debugTabLookup(identifier)
        XCTFail("Tab \(identifier) did not become selected")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
    }

    func testNavigateToDetailAndToggleFavorite() {
        tapTab("catalog")

        tapElement("stage38.catalog.open.identity")
        XCTAssertTrue(app.staticTexts["stage38.detail.title"].waitForExistence(timeout: 1.0))

        app.buttons["stage38.detail.favorite.identity"].tap()

        app.buttons["stage38.detail.backButton"].tap()
        XCTAssertEqual(app.staticTexts["stage38.favoritesCountLabel"].label, "Favorites count: 1")
    }

    func testSearchFiltersResults() {
        tapTab("search")

        let searchField = app.textFields["stage38.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 1.0))
        searchField.tap()
        searchField.typeText("state")

        XCTAssertEqual(app.staticTexts["stage38.searchResultsCount"].label, "Results: 1")
        XCTAssertTrue(app.staticTexts["stage38.search.result.state"].exists)
    }

    func testLogoutResetsTabAndNavigationState() {
        tapTab("catalog")
        app.buttons["stage38.catalog.open.identity"].tap()

        tapTab("profile")
        app.buttons["stage38.logoutButton"].tap()

        XCTAssertEqual(app.staticTexts["stage38.sessionStateLabel"].label, "Session: signed out")
        XCTAssertEqual(app.staticTexts["stage38.pathCountLabel"].label, "Catalog path count: 0")
        XCTAssertEqual(app.buttons["stage38.tab.home"].value as? String, "selected")
    }
}
