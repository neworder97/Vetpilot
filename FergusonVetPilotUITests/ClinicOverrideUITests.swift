import XCTest

final class ClinicOverrideUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { print("CLINIC_OVERRIDE_UI_FAILURE=" + XCUIApplication().debugDescription) }
    }

    private func approve(_ control: XCUIElement, in app: XCUIApplication) {
        reveal(control, in: app)
        if control.value as? String != "1" {
            // SwiftUI exposes the whole labeled row as a switch; tap the actual toggle.
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let checked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [checked], timeout: 5), .completed)
    }

    private func saveOverride(in app: XCUIApplication) {
        let save = app.buttons["clinicOverride.save"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        save.tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<30 {
            let frame = element.exists ? element.frame : .zero
            if element.exists && element.isHittable && frame.minY >= 150 && frame.maxY <= app.frame.maxY - 50 { return }
            let down = element.exists && !frame.isEmpty ? frame.minY < 150 : towardTop
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.42 : 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.72 : 0.42))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }

    private func open(_ name: String, matching predicate: NSPredicate, in app: XCUIApplication) {
        let searchButton = app.buttons["workspace.search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 10)); searchButton.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(name)
        let medication = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(medication.waitForExistence(timeout: 5)); medication.tap()
    }

    private func replace(_ field: XCUIElement, with value: String, in app: XCUIApplication) {
        reveal(field, in: app)
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
        let done = app.buttons["clinicOverride.keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3)); done.tap()
    }

    func testLiquidOverrideSavesDoseAndConcentrationAcrossAppRelaunchAndCanBeDisabled() {
        let app = XCUIApplication(); app.launchArguments = ["ui-no-cloud"]; app.launch()
        let match = NSPredicate(format: "label BEGINSWITH 'Capromorelin' AND label CONTAINS 'Entyce'")
        open("Capromorelin", matching: match, in: app)
        let edit = app.buttons["dose.protocol.override"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, in: app); edit.tap()
        replace(app.textFields["clinicOverride.minimum"], with: "3", in: app)
        replace(app.textFields["clinicOverride.maximum"], with: "3", in: app)
        replace(app.textFields["clinicOverride.concentration"], with: "15", in: app)
        let approved = app.switches["clinicOverride.approved"]
        approve(approved, in: app)
        saveOverride(in: app)
        let concentration = app.textFields["dose.concentration"]
        reveal(concentration, in: app); XCTAssertTrue(concentration.exists)
        XCTAssertEqual(Double(concentration.value as? String ?? ""), 15)
        // The catalog's clinical note remains alongside the clinic-entered equation.
        let note = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Current label advises caution in dogs'")).firstMatch
        reveal(note, in: app, towardTop: true); XCTAssertTrue(note.exists)

        app.terminate(); app.launch()
        open("Capromorelin", matching: match, in: app)
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, in: app); edit.tap()
        XCTAssertEqual(Double(app.textFields["clinicOverride.minimum"].value as? String ?? ""), 3)
        let savedConcentration = app.textFields["clinicOverride.concentration"]
        reveal(savedConcentration, in: app)
        XCTAssertEqual(Double(savedConcentration.value as? String ?? ""), 15)
        app.buttons["Cancel"].tap()
        let disable = app.buttons["dose.protocol.disable"]
        reveal(disable, in: app, towardTop: true); disable.tap()
        reveal(concentration, in: app)
        XCTAssertEqual(Double(concentration.value as? String ?? ""), 30)
    }

    func testGabapentinSpecialCalculatorExposesClinicOverrideEditor() {
        let app = XCUIApplication(); app.launchArguments = ["ui-no-cloud"]; app.launch()
        open("Gabapentin", matching: NSPredicate(format: "label BEGINSWITH 'Gabapentin' AND label CONTAINS 'Capsule'"), in: app)
        let edit = app.buttons["dose.protocol.override"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        XCTAssertTrue(app.textFields["clinicOverride.minimum"].waitForExistence(timeout: 5))
        XCTAssertEqual(Double(app.textFields["clinicOverride.minimum"].value as? String ?? ""), 10)
        let approved = app.switches["clinicOverride.approved"]
        approve(approved, in: app)
        saveOverride(in: app)
        let disable = app.buttons["dose.protocol.disable"]
        XCTAssertTrue(disable.waitForExistence(timeout: 5)); reveal(disable, in: app, towardTop: true)
        disable.tap()
        let calculate = app.buttons["gabapentin.calculate"]
        reveal(calculate, in: app); XCTAssertTrue(calculate.exists)
    }

    func testTabletMedicationExposesClinicOverrideEditor() {
        let app = XCUIApplication(); app.launchArguments = ["ui-no-cloud"]; app.launch()
        open("Carprofen", matching: NSPredicate(format: "label BEGINSWITH 'Carprofen'"), in: app)
        let edit = app.buttons["dose.protocol.override"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.textFields["clinicOverride.minimum"].waitForExistence(timeout: 5))
        XCTAssertEqual(Double(app.textFields["clinicOverride.minimum"].value as? String ?? ""), 4.4)
        XCTAssertTrue(app.textFields["mg strengths, comma separated"].exists)
        app.buttons["Cancel"].tap()
    }
}
