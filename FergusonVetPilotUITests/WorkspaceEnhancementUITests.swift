import XCTest
final class WorkspaceEnhancementUITests:XCTestCase {
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
        let medication=app.buttons.containing(.staticText,identifier:"Carprofen · Tablet").firstMatch
        XCTAssertTrue(medication.waitForExistence(timeout:5));medication.tap()
        let weight=app.textFields["dose.sheet.weight"];XCTAssertTrue(weight.waitForExistence(timeout:5));weight.tap();weight.typeText("10")
        if app.buttons["dose.keyboard.done"].exists {app.buttons["dose.keyboard.done"].tap()}
        let kg=app.buttons["kg"];if kg.exists && kg.isHittable {kg.tap()}
        func reveal(_ element:XCUIElement) {for _ in 0..<18 where !element.isHittable {app.swipeUp()};XCTAssertTrue(element.isHittable)}
        let calculate=app.buttons["dose.calculate"];reveal(calculate);calculate.tap()
        let save=app.buttons["Save this calculation"];reveal(save);XCTAssertTrue(save.isEnabled);save.tap()
        let reopen=app.buttons.matching(NSPredicate(format:"label BEGINSWITH 'Reopen '")).firstMatch
        XCTAssertTrue(reopen.waitForExistence(timeout:5));reveal(reopen);reopen.tap()
        XCTAssertFalse(app.staticTexts["dose.candidate.amount"].exists)
        for _ in 0..<18 where !calculate.isHittable {app.swipeDown()}
        XCTAssertTrue(calculate.isHittable);calculate.tap()
        XCTAssertTrue(app.staticTexts["dose.candidate.amount"].waitForExistence(timeout:5))
    }

}
