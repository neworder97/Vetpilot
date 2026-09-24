import XCTest

final class ScribeUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false; app = XCUIApplication(); app.launchArguments = ["ui-scribe-local", "ui-no-cloud"]; app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 10))
    }
    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { print("SCRIBE_UI_FAILURE=\(app.debugDescription)") }
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func tab(_ name: String) {
        if app.tabBars.buttons[name].exists { app.tabBars.buttons[name].tap() }
        else {
            let more = app.tabBars.buttons["More"]
            XCTAssertTrue(more.waitForExistence(timeout: 10))
            more.tap()
            let target = app.staticTexts[name].firstMatch
            // A cold relaunch can finish laying out the tab controller after the first tap.
            if !target.waitForExistence(timeout: 5) { more.tap() }
            XCTAssertTrue(target.waitForExistence(timeout: 5)); target.tap()
        }
    }
    func keyboardDone() { if app.buttons["scribe.keyboard.done"].exists { app.buttons["scribe.keyboard.done"].tap() } }
    func reach(_ element: XCUIElement) {
        for _ in 0..<16 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    func create(_ name: String) {
        tab("Scribe"); let new = app.buttons["scribe.new"]; XCTAssertTrue(new.waitForExistence(timeout: 5)); new.tap()
        let field = app.textFields["scribe.patient.name"].firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 4)); field.tap(); field.typeText(name); keyboardDone()
        let create = app.buttons["scribe.create"]; reach(create); create.tap()
        let saved = app.staticTexts[name].firstMatch; XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
    }
    func testManualDraftEditFinalizeAndPDF() {
        create("ScribeManual" + String(Int(Date().timeIntervalSince1970)))
        let transcript = app.textViews["scribe.transcript"]; reach(transcript); transcript.tap(); transcript.typeText("No vomiting. Weight is 12.5 kg. Takes 0.25 mL."); keyboardDone()
        let draft = app.buttons["scribe.draft"]; reach(draft); draft.tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scribe.note.")).firstMatch
        reach(note); note.tap()
        let history = app.textViews["scribe.note.subjective"]; XCTAssertTrue(history.waitForExistence(timeout: 5)); XCTAssertTrue((history.value as? String ?? "").contains("12.5 kg")); XCTAssertTrue((history.value as? String ?? "").contains("0.25 mL"))
        let reviewer = app.textFields["scribe.reviewer"]; reach(reviewer); reviewer.tap(); reviewer.typeText("Dr Simulator"); keyboardDone()
        let finalize = app.buttons["scribe.finalize"]; reach(finalize); finalize.tap()
        let pdf = app.buttons["scribe.pdf"]; reach(pdf); pdf.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 6) || app.buttons["Copy"].exists || app.buttons["Print"].exists)
    }
    func testRecordingContinuesAcrossTabsAndGlobalControls() {
        let monitor = addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        create("ScribeRecording" + String(Int(Date().timeIntervalSince1970)))
        let consent = app.switches["scribe.consent"]; reach(consent)
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(consent.value as? String, "1")
        let record = app.buttons["scribe.record"]; reach(record); XCTAssertTrue(record.isEnabled); record.tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if permission.waitForExistence(timeout: 10) {
            if permission.buttons["Allow"].exists { permission.buttons["Allow"].tap() }
            else if permission.buttons["OK"].exists { permission.buttons["OK"].tap() }
        }
        let stop = app.buttons["scribe.global.stop"]; XCTAssertTrue(stop.waitForExistence(timeout: 60))
        tab("Dose"); XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 5)); XCTAssertTrue(stop.exists)
        app.buttons["scribe.global.pause"].tap(); XCTAssertTrue(app.buttons["scribe.global.pause"].label.contains("Resume"))
        app.buttons["scribe.global.pause"].tap(); XCTAssertTrue(app.buttons["scribe.global.pause"].label.contains("Pause"))
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = "Recording-across-Dose-tab-red-border"; image.lifetime = .keepAlways; add(image)
        stop.tap(); XCTAssertFalse(stop.exists)
    }
    func testUnconfiguredAccountDoesNotPretendToSignIn() {
        app.buttons["app.settings"].tap()
        let status = app.staticTexts["account.notConfigured"]; XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["account.email.submit"].isEnabled)
    }
    func testGuestScribeRequiresAccount() {
        app.terminate(); app.launchArguments = ["ui-no-cloud"]; app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 10))
        tab("Scribe")
        XCTAssertTrue(app.buttons["Create account or sign in"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scribe.new"].exists)
        app.buttons["Create account or sign in"].tap()
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["Password"].exists)
    }

}
