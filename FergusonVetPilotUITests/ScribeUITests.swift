import XCTest
// The retired Scribe UI suite is replaced with coverage of its successor.
final class ScribeUITests: XCTestCase {
    func testCytologyReplacesScribeAndRequiresLabeledImage() {
        let app = XCUIApplication(); app.launchArguments = ["ui-no-cloud"]; app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 15))
        if app.tabBars.buttons["Cytology"].exists { app.tabBars.buttons["Cytology"].tap() }
        else { app.tabBars.buttons["More"].tap(); let target = app.staticTexts["Cytology"].firstMatch; XCTAssertTrue(target.waitForExistence(timeout: 10)); target.tap() }
        XCTAssertFalse(app.buttons["scribe.new"].exists)
        let add = app.buttons["cytology.new"]; XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        let title = app.textFields["cytology.title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Ear yeast learning sample")
        app.buttons["cytology.save"].tap()
        XCTAssertTrue(app.staticTexts["Add an image and a label for every image."].waitForExistence(timeout: 5))
    }
}
