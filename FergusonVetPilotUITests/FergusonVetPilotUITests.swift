import XCTest

final class FergusonVetPilotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 8))
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { print("UI_FAILURE_HIERARCHY=\(app.debugDescription)") }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLabworkSearchAndPreparation() throws {
        app.tabBars.buttons["Labwork"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("20011")
        let thyroid = app.buttons["labwork.test.MSU-20011"]
        XCTAssertTrue(thyroid.waitForExistence(timeout: 4))
        thyroid.tap()
        XCTAssertTrue(app.staticTexts["labwork.amount"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["labwork.amount"].label, "2 mL")
        let preparation = app.staticTexts["labwork.preparation"]
        for _ in 0..<5 where !preparation.exists { app.swipeUp() }
        XCTAssertTrue(preparation.label.contains("30–60"))
    }

    func testNutritionOversizedInputDoesNotCrash() throws {
        app.tabBars.buttons["Nutrition"].tap()
        app.segmentedControls.buttons["kg"].tap()
        let weight = app.textFields["nutrition.weight"]
        weight.tap()
        weight.typeText("1000000000000000000000000")
        app.buttons["nutrition.keyboard.done"].tap()
        let invalid = app.staticTexts["Enter a valid weight to calculate calories"]
        for _ in 0..<8 where !invalid.exists { app.swipeUp() }
        XCTAssertTrue(invalid.exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCoreVetPilotFlow() throws {
        XCTAssertTrue(app.staticTexts["Ferguson VetPilot"].exists)
        XCTAssertTrue(app.tabBars.buttons["Dose"].exists)
        XCTAssertTrue(app.tabBars.buttons["X-Ray"].exists)
        XCTAssertTrue(app.tabBars.buttons["Breeds"].exists)
        XCTAssertTrue(app.tabBars.buttons["Nutrition"].exists)

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
        for _ in 0..<12 {
            if q12.exists && q12.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(q12.waitForExistence(timeout: 3))
        q12.tap()

        let overrideWarning = app.staticTexts["dose.frequency.override.warning"]
        for _ in 0..<5 where !overrideWarning.isHittable { app.swipeUp() }
        XCTAssertTrue(overrideWarning.exists)

        // This specific 25-mg strength cannot exactly deliver the fixed 22-mg
        // per-administration target. It must not become a dispense instruction.
        let blocked = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "outside the selected dose range")).firstMatch
        for _ in 0..<6 where !blocked.isHittable { app.swipeDown() }
        XCTAssertTrue(blocked.exists)
        XCTAssertFalse(app.buttons["dose.supply.7"].exists)

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

        let gate = app.descendants(matching: .any).matching(identifier: "radiology.xrayGate").firstMatch
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
        for _ in 0..<12 {
            if injectableNotice.exists { break }
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

    // Prepared for the next real iOS Simulator run; not a claim of execution.
    func testNutritionTabDogAndCatSmokeFlow() throws {
        app.tabBars.buttons["Nutrition"].tap()
        XCTAssertTrue(app.staticTexts["Nutrition & weight plan"].waitForExistence(timeout: 4))
        let weight = app.textFields["nutrition.weight"]
        XCTAssertTrue(weight.exists)
        app.segmentedControls.buttons["kg"].tap()
        weight.tap()
        weight.typeText("12")
        app.buttons["nutrition.keyboard.done"].tap()
        let score = app.buttons["nutrition.bcs.7"]
        for _ in 0..<6 where !score.isHittable { app.swipeUp() }
        XCTAssertTrue(score.isHittable)
        score.tap()
        let calories = app.staticTexts["Recommended starting calories"]
        for _ in 0..<6 where !calories.isHittable { app.swipeUp() }
        XCTAssertTrue(calories.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "394 kcal/day")).firstMatch.exists)
        let cat = app.segmentedControls.buttons["Cat"]
        for _ in 0..<6 where !cat.isHittable { app.swipeDown() }
        cat.tap()
        weight.tap()
        let prior = weight.value as? String ?? "12"
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count))
        weight.typeText("6")
        app.buttons["nutrition.keyboard.done"].tap()
        for _ in 0..<6 where !calories.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "187 kcal/day")).firstMatch.exists)
    }

    func testInvalidConcentrationCannotCalculate() throws {
        let search = app.textFields["Search medications…"]
        search.tap()
        search.typeText("Metacam maintenance")
        let medication = app.staticTexts["Meloxicam (Metacam maintenance)"]
        XCTAssertTrue(medication.waitForExistence(timeout: 4))
        medication.tap()
        let weight = app.textFields["dose.sheet.weight"]
        weight.tap()
        weight.typeText("22.046226218")
        if app.buttons["dose.keyboard.done"].exists { app.buttons["dose.keyboard.done"].tap() }
        let concentration = app.textFields["dose.concentration"]
        for _ in 0..<4 where !concentration.isHittable { app.swipeUp() }
        concentration.tap()
        let prior = concentration.value as? String ?? "1.5"
        concentration.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count))
        concentration.typeText("0")
        XCTAssertTrue(app.staticTexts["dose.concentration.error"].exists)
        XCTAssertFalse(app.buttons["dose.calculate"].isEnabled)
    }
}
