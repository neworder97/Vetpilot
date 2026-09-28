import XCTest
final class WorkspaceEnhancementUITests:XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false,
                        file: StaticString = #filePath, line: UInt = #line) {
        let top = app.frame.minY + 150
        let bottom = app.frame.maxY - 50
        for _ in 0..<32 {
            let exists = element.exists
            let frame = exists ? element.frame : .zero
            if exists && element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            let down = exists && !frame.isEmpty ? frame.minY < top : towardTop
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.46 : 0.64))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.64 : 0.46))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minY, top, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom, file: file, line: line)
    }

    func testGlobalSearchOpensExistingBreedAndLabAndPersistsFavorite() {
        let app=XCUIApplication();app.launch()
        let searchButton=app.buttons["workspace.search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout:8));searchButton.tap()
        let search=app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("French Bulldog")
        let favorite=app.buttons["Favorite French Bulldog"];XCTAssertTrue(favorite.waitForExistence(timeout:5));favorite.tap()
        let result=app.buttons.containing(.staticText,identifier:"French Bulldog").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout:5));result.tap()
        XCTAssertTrue(app.staticTexts["French Bulldog"].waitForExistence(timeout:5))
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["★ French Bulldog"].waitForExistence(timeout:8))
        searchButton.tap();XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("CBC with Differential")
        let lab=app.buttons.containing(.staticText,identifier:"CBC with Differential").firstMatch;XCTAssertTrue(lab.waitForExistence(timeout:5));lab.tap()
        XCTAssertTrue(app.staticTexts["labwork.amount"].waitForExistence(timeout:5))
        let screenshot=XCTAttachment(screenshot:XCUIScreen.main.screenshot());screenshot.lifetime = .keepAlways;add(screenshot)
    }
    func testCalculationRecallReusesInputsAndRequiresRecalculation() {
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(app.buttons["workspace.search"].waitForExistence(timeout:8));app.buttons["workspace.search"].tap()
        let search=app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("Carprofen")
        let medication=app.buttons.matching(NSPredicate(format:"label BEGINSWITH 'Carprofen'")).firstMatch
        XCTAssertTrue(medication.waitForExistence(timeout:5));medication.tap()
        let weight=app.textFields["dose.sheet.weight"];XCTAssertTrue(weight.waitForExistence(timeout:5));weight.tap();weight.typeText("10")
        if app.buttons["dose.keyboard.done"].exists {app.buttons["dose.keyboard.done"].tap()}
        let kg=app.buttons["kg"];if kg.exists && kg.isHittable {kg.tap()}
        let calculate=app.buttons["dose.calculate"]
        reveal(calculate,in:app);XCTAssertTrue(calculate.isEnabled)
        calculate.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        let candidate=app.staticTexts["dose.candidate.amount"]
        XCTAssertTrue(candidate.waitForExistence(timeout:5))
        // Calculate intentionally scrolls to the candidate. Quick access is
        // above that result, so find Save toward earlier fields, not below it.
        let save=app.buttons["Save this calculation"]
        reveal(save,in:app,towardTop:true);XCTAssertTrue(save.isEnabled);save.tap()
        let reopen=app.buttons.matching(NSPredicate(format:"label BEGINSWITH 'Reopen '")).firstMatch
        XCTAssertTrue(reopen.waitForExistence(timeout:5));reveal(reopen,in:app);reopen.tap()
        XCTAssertFalse(candidate.exists)
        reveal(weight,in:app,towardTop:true)
        XCTAssertEqual(Double(weight.value as? String ?? "") ?? .nan,10,accuracy:0.00001)
        reveal(calculate,in:app);XCTAssertTrue(calculate.isEnabled)
        calculate.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        XCTAssertTrue(candidate.waitForExistence(timeout:5))
    }

}
