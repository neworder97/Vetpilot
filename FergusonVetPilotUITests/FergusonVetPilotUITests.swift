import XCTest

final class FergusonVetPilotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 8))
    }

    func testCoreVetPilotFlow() throws {
        XCTAssertTrue(app.staticTexts["Ferguson VetPilot"].exists)
        XCTAssertTrue(app.tabBars.buttons["Dose"].exists)
        XCTAssertTrue(app.tabBars.buttons["X-Ray"].exists)
        XCTAssertTrue(app.tabBars.buttons["Breeds"].exists)

        let custom = app.buttons["dose.custom"]
        XCTAssertTrue(custom.waitForExistence(timeout: 3))
        custom.tap()
        XCTAssertTrue(app.navigationBars["Custom medications"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        // Reproduces the reported issue: open medication first, then enter weight in the sheet.
        let search = app.textFields["Search medications…"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("carprofen")

        let carprofen = app.staticTexts["Carprofen (Rimadyl)"]
        XCTAssertTrue(carprofen.waitForExistence(timeout: 3))
        carprofen.tap()

        let sheetWeight = app.textFields["dose.sheet.weight"]
        XCTAssertTrue(sheetWeight.waitForExistence(timeout: 3))
        sheetWeight.tap()
        sheetWeight.typeText("22.046226218")

        let keyboardDone = app.buttons["dose.keyboard.done"]
        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        }

        let calculate = app.buttons["dose.calculate"]
        XCTAssertTrue(calculate.waitForExistence(timeout: 3))
        XCTAssertTrue(calculate.isEnabled)
        calculate.tap()

        let doseResult = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "44 mg")).firstMatch
        XCTAssertTrue(doseResult.waitForExistence(timeout: 3))

        let q12 = app.buttons["dose.frequency.q12h"]
        if !q12.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(q12.waitForExistence(timeout: 3))
        q12.tap()

        let overrideWarning = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "Choosing an override changes schedule/supply math only"))
            .firstMatch
        if !overrideWarning.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(overrideWarning.waitForExistence(timeout: 3))

        let sevenDays = app.buttons["dose.supply.7"]
        if !sevenDays.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(sevenDays.waitForExistence(timeout: 3))
        sevenDays.tap()
        let supplySummary = app.staticTexts["dose.supply.summary"]
        XCTAssertTrue(supplySummary.waitForExistence(timeout: 3))
        XCTAssertTrue(supplySummary.label.contains("q12h"))

        app.buttons["dose.done"].tap()

        // Production X-ray screen must never manufacture a result when no radiograph is loaded.
        app.tabBars.buttons["X-Ray"].tap()
        XCTAssertTrue(app.staticTexts["Radiology AI Second Look"].waitForExistence(timeout: 3))
        let secondLook = app.buttons["radiology.secondLook"]
        XCTAssertTrue(secondLook.waitForExistence(timeout: 3))
        secondLook.tap()
        XCTAssertFalse(app.navigationBars["X-Ray Second Look"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Load a radiograph first."].waitForExistence(timeout: 3))

        app.tabBars.buttons["Breeds"].tap()
        XCTAssertTrue(app.staticTexts["Breed predisposition library"].waitForExistence(timeout: 3))
        let breedSearch = app.textFields["Search breed or condition…"]
        XCTAssertTrue(breedSearch.waitForExistence(timeout: 3))
        breedSearch.tap()
        breedSearch.typeText("German")
        XCTAssertTrue(app.staticTexts["German Shepherd Dog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Hip/elbow dysplasia")).firstMatch.waitForExistence(timeout: 3))
    }

    func testLiveRadiographImportAndProductionSecondLook() throws {
        app.tabBars.buttons["X-Ray"].tap()
        XCTAssertTrue(app.staticTexts["Radiology AI Second Look"].waitForExistence(timeout: 4))

        let region = app.textFields["Study/region + view — thorax lateral, thorax VD, abdomen…"]
        XCTAssertTrue(region.waitForExistence(timeout: 3))
        region.tap()
        region.typeText("thorax VD")

        let importButton = app.buttons["Import X-ray"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 3))
        importButton.tap()

        // The CI simulator receives a real canine VD thoracic radiograph via
        // `xcrun simctl addmedia`. We select that actual image through the
        // production PhotosPicker; no scan result is injected or mocked.
        let photosNav = app.navigationBars["Photos"]
        XCTAssertTrue(photosNav.waitForExistence(timeout: 8), "System PhotosPicker did not appear")

        let firstPhoto = app.images
            .matching(NSPredicate(format: "identifier == 'PXGGridLayout-Info' AND label BEGINSWITH[c] 'Photo'"))
            .firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 8), "No simulator photo was visible in PhotosPicker")
        // PhotosPicker can expose a visible thumbnail with isHittable=false on Simulator.
        // Tap the center coordinate of that real photo frame; no image/result is injected.
        firstPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Depending on the iOS PhotosPicker version, single selection may either
        // dismiss immediately or wait for an Add/Done confirmation. Track the actual
        // Photos navigation bar, not the privacy banner, because that banner may
        // disappear while the picker is still on-screen.
        if photosNav.exists {
            let add = app.buttons["Add"]
            let done = app.buttons["Done"]
            if add.waitForExistence(timeout: 3) {
                add.tap()
            } else if done.waitForExistence(timeout: 3) {
                done.tap()
            }
        }

        let pickerDismissed = NSPredicate(format: "exists == false")
        expectation(for: pickerDismissed, evaluatedWith: photosNav)
        waitForExpectations(timeout: 10)

        let gate = app.staticTexts
            .matching(NSPredicate(format: "identifier == %@ AND (label == %@ OR label == %@ OR label == %@)",
                                  "radiology.precheck",
                                  "Likely radiograph",
                                  "Uncertain",
                                  "Does not look like a radiograph"))
            .firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 20), "Production X-ray precheck did not finish")
        XCTAssertFalse(gate.label.contains("Does not look like"), "Real radiograph was rejected by production precheck")

        let scan = app.buttons["radiology.secondLook"]
        if !scan.waitForExistence(timeout: 2) || !scan.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(scan.waitForExistence(timeout: 3))
        scan.tap()

        let analyzeAnyway = app.buttons["Analyze anyway"]
        if analyzeAnyway.waitForExistence(timeout: 3) {
            analyzeAnyway.tap()
        }

        let resultsTitle = app.navigationBars["X-Ray Second Look"]
        XCTAssertTrue(resultsTitle.waitForExistence(timeout: 40), "Production second-look result did not appear")

        // The result is a multi-page Form. The first production pattern opinion
        // is intentionally below the image/precheck summary on smaller iPhones,
        // so scroll the real result UI until that opinion is materialized.
        let topOpinion = app.staticTexts["radiology.ai.topDifferential"]
        if !topOpinion.waitForExistence(timeout: 3) {
            for _ in 0..<5 {
                app.swipeUp()
                if topOpinion.waitForExistence(timeout: 2) { break }
            }
        }
        XCTAssertTrue(topOpinion.exists, "No production pattern opinion was displayed")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "VetPilot live production X-ray result"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testInjectableIsSingleDoseOnly() throws {
        let search = app.textFields["Search medications…"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Cerenia Injectable")

        let cerenia = app.staticTexts["Maropitant citrate (Cerenia Injectable)"].firstMatch
        XCTAssertTrue(cerenia.waitForExistence(timeout: 3))
        cerenia.tap()

        let sheetWeight = app.textFields["dose.sheet.weight"]
        XCTAssertTrue(sheetWeight.waitForExistence(timeout: 3))
        sheetWeight.tap()
        sheetWeight.typeText("22.046226218")

        let keyboardDone = app.buttons["dose.keyboard.done"]
        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        }

        let calculate = app.buttons["dose.calculate"]
        XCTAssertTrue(calculate.waitForExistence(timeout: 3))
        calculate.tap()

        let injectableNotice = app.staticTexts["dose.injectable.single"]
        if !injectableNotice.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(injectableNotice.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["dose.supply.7"].exists)
        XCTAssertFalse(app.buttons["dose.supply.14"].exists)
        XCTAssertFalse(app.buttons["dose.supply.30"].exists)
    }

    func testDemoRecordingFlow() throws {
        sleep(1)

        let search = app.textFields["Search medications…"]
        search.tap()
        search.typeText("gabapentin")

        let gabapentin = app.staticTexts["Gabapentin (Neurontin)"].firstMatch
        XCTAssertTrue(gabapentin.waitForExistence(timeout: 3))
        gabapentin.tap()

        let sheetWeight = app.textFields["dose.sheet.weight"]
        XCTAssertTrue(sheetWeight.waitForExistence(timeout: 3))
        sheetWeight.tap()
        sheetWeight.typeText("22.046226218")

        let keyboardDone = app.buttons["dose.keyboard.done"]
        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        }

        app.buttons["dose.calculate"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "100–150 mg")).firstMatch.waitForExistence(timeout: 3))
        sleep(2)

        app.buttons["dose.done"].tap()
        app.tabBars.buttons["X-Ray"].tap()
        XCTAssertTrue(app.staticTexts["Radiology AI Second Look"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["radiology.secondLook"].waitForExistence(timeout: 3))
        sleep(2)

        app.tabBars.buttons["Breeds"].tap()
        let breedSearch = app.textFields["Search breed or condition…"]
        breedSearch.tap()
        breedSearch.typeText("German")
        XCTAssertTrue(app.staticTexts["German Shepherd Dog"].waitForExistence(timeout: 3))
        sleep(3)
    }
}
