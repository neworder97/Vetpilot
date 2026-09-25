import XCTest

final class SyncControlsUITests: XCTestCase {
    func testGuestSyncControlsLeadToSignInWithoutClaimingToSync() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["ui-no-cloud"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 15))
        app.tabBars.buttons["My Clinic"].tap()
        let signIn = app.buttons["clinic.sync.signin"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        for _ in 0..<6 where !signIn.isHittable { app.swipeUp() }
        signIn.tap()
        XCTAssertTrue(app.buttons["account.email.submit"].waitForExistence(timeout: 5))
        let status = app.staticTexts["account.sync.status"]
        for _ in 0..<6 where !status.isHittable { app.swipeUp() }
        XCTAssertTrue(status.label.contains("Sign in"))
        XCTAssertFalse(app.buttons["account.sync.now"].isEnabled)
    }
}
