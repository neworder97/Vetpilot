import XCTest

final class NutritionSelectorAuditUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Nutrition"].tap()
    }
    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { print(app.debugDescription) }
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.lifetime = .keepAlways; add(image)
    }
    private func reveal(_ element: XCUIElement, up: Bool = false) {
        for _ in 0..<25 {
            if element.exists && element.isHittable && element.frame.minY >= 160 && element.frame.maxY < app.frame.maxY - 80 { return }
            let towardTop = element.exists ? element.frame.minY < 160 : up
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardTop ? 0.4 : 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardTop ? 0.72 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Unable to reveal \(element)")
    }
    private func enter(_ field: XCUIElement, _ value: String) {
        reveal(field, up: true); field.tap()
        let old = field.value as? String ?? ""
        if Double(old) != nil { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        field.typeText(value)
        app.buttons["nutrition.keyboard.done"].tap()
    }
    private func verify(_ score: Int, _ status: String, _ expected: String?) {
        let statusButton = app.segmentedControls.buttons[status]
        reveal(statusButton, up: true); statusButton.tap()
        XCTAssertTrue(statusButton.isSelected)
        let scoreButton = app.buttons["nutrition.bcs.\(score)"]
        reveal(scoreButton); scoreButton.tap()
        XCTAssertTrue(scoreButton.isSelected, "BCS \(score) did not become selected")
        let output = app.staticTexts[expected == nil ? "nutrition.result.unavailable" : "nutrition.result.calories"]
        reveal(output)
        if let expected { XCTAssertEqual(output.label, expected + " kcal/day") }
        else { XCTAssertTrue(output.exists); XCTAssertFalse(app.staticTexts["nutrition.result.calories"].exists) }
        print("NUTRITION_AUDIT BCS=\(score) status=\(status) result=\(output.label)")
    }
    func testDog95PoundsEveryBCSAndBothStatuses() {
        enter(app.textFields["nutrition.weight"], "95")
        let neutered: [String?] = [nil,nil,nil,nil,"1648","986","822","774","732"]
        let intact: [String?] = [nil,nil,nil,nil,"1883","986","822","774","732"]
        for score in 1...9 {
            verify(score,"Spayed / Neutered",neutered[score-1])
            verify(score,"Intact",intact[score-1])
        }
        // Return to the originally reported selection to expose stale-result caching.
        verify(6,"Spayed / Neutered","986")
        verify(5,"Intact","1883")
    }
    func testCatFourKilogramsEveryBCSAndBothStatuses() {
        app.segmentedControls.buttons["Cat"].tap()
        app.segmentedControls.buttons["kg"].tap()
        enter(app.textFields["nutrition.weight"], "4")
        let neutered: [String?] = [nil,nil,nil,"205","238","165","137","131","125"]
        let intact: [String?] = [nil,nil,nil,"205","277","165","137","131","125"]
        for score in 1...9 {
            verify(score,"Spayed / Neutered",neutered[score-1])
            verify(score,"Intact",intact[score-1])
        }
    }
}
