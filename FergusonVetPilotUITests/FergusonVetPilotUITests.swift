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

    func testIDEXXSendOutSearchSpecimensAndWellnessComponents() throws {
        app.tabBars.buttons["Labwork"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("bnp dog")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        let canineBNP = app.buttons["labwork.test.IDEXX-2665"]
        XCTAssertTrue(canineBNP.waitForExistence(timeout: 4))
        for _ in 0..<6 where !canineBNP.isHittable { app.swipeUp() }
        XCTAssertTrue(canineBNP.isHittable)
        canineBNP.tap()

        let amount = app.staticTexts["labwork.amount"]
        for _ in 0..<6 where !amount.isHittable { app.swipeUp() }
        XCTAssertEqual(amount.label, "1 mL separated EDTA plasma")
        let preparation = app.staticTexts["labwork.preparation"]
        for _ in 0..<6 where !preparation.isHittable { app.swipeUp() }
        XCTAssertTrue(preparation.label.contains("Do not clot"))

        app.navigationBars.buttons["Labwork"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 4))
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "bnp dog".count))
        search.typeText("young wellness")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        let youngWellness = app.buttons["labwork.test.IDEXX-2807"]
        XCTAssertTrue(youngWellness.waitForExistence(timeout: 4))
        for _ in 0..<6 where !youngWellness.isHittable { app.swipeUp() }
        XCTAssertTrue(youngWellness.isHittable)
        youngWellness.tap()

        let components = app.staticTexts["labwork.components"]
        for _ in 0..<6 where !components.isHittable { app.swipeUp() }
        XCTAssertTrue(components.label.contains("Chem 10"))
        XCTAssertTrue(components.label.contains("CBC-Select"))
        for _ in 0..<6 where !amount.isHittable { app.swipeUp() }
        XCTAssertEqual(amount.label, "2 mL serum + 1 mL EDTA whole blood")
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
        XCTAssertTrue(app.staticTexts["VetPilot"].exists)
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
        let quantity = app.staticTexts["dose.result.quantity"]
        for _ in 0..<4 where !quantity.exists { app.swipeUp() }
        XCTAssertTrue(quantity.exists)
        XCTAssertTrue(quantity.label.contains("tablet(s) equivalent"))


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

    func testNutritionTabDogAndCatSmokeFlow() throws {
        app.tabBars.buttons["Nutrition"].tap()
        XCTAssertTrue(app.staticTexts["Nutrition & weight plan"].waitForExistence(timeout: 4))
        let weight = app.textFields["nutrition.weight"]
        XCTAssertTrue(weight.exists)
        app.segmentedControls.buttons["kg"].tap()
        replaceNutritionText(weight, with: "12")
        let score = app.buttons["nutrition.bcs.7"]
        scrollNutritionTo(score)
        score.tap()
        let status = app.staticTexts["nutrition.result.status"]
        scrollNutritionTo(status)
        XCTAssertEqual(status.label, "Obese (PNA)")
        XCTAssertEqual(app.staticTexts["nutrition.result.idealWeight"].label, "~10 kg / 22.05 lb")
        assertNutritionCalories("315 kcal/day")
        let cat = app.segmentedControls.buttons["Cat"]
        scrollNutritionTo(cat, towardTop: true)
        cat.tap()
        replaceNutritionText(weight, with: "6")
        scrollNutritionTo(status)
        XCTAssertEqual(status.label, "Obese (PNA)")
        XCTAssertEqual(app.staticTexts["nutrition.result.idealWeight"].label, "~5 kg / 11.03 lb")
        assertNutritionCalories("187 kcal/day")
    }

    func testNutritionReproductiveStatusAndWeightUnitConversion() throws {
        app.tabBars.buttons["Nutrition"].tap()
        app.segmentedControls.buttons["kg"].tap()
        let weight = app.textFields["nutrition.weight"]
        replaceNutritionText(weight, with: "10")
        assertNutritionCalories("551 kcal/day")

        let intact = app.segmentedControls.buttons["Intact"]
        scrollNutritionTo(intact, towardTop: true)
        intact.tap()
        assertNutritionCalories("630 kcal/day")

        let pounds = app.segmentedControls.buttons["lb"]
        scrollNutritionTo(pounds, towardTop: true)
        pounds.tap()
        XCTAssertEqual(Double(weight.value as? String ?? "") ?? .nan, 22.05, accuracy: 0.00001)
        let currentWeight = app.staticTexts["nutrition.result.weight"]
        scrollNutritionTo(currentWeight)
        XCTAssertEqual(currentWeight.label, "22.05 lb / 10 kg")
        assertNutritionCalories("630 kcal/day")

        let cat = app.segmentedControls.buttons["Cat"]
        scrollNutritionTo(cat, towardTop: true)
        cat.tap()
        app.segmentedControls.buttons["kg"].tap()
        replaceNutritionText(weight, with: "4")
        assertNutritionCalories("277 kcal/day")
        let neutered = app.segmentedControls.buttons["Spayed / Neutered"]
        scrollNutritionTo(neutered, towardTop: true)
        neutered.tap()
        let status = app.staticTexts["nutrition.result.status"]
        scrollNutritionTo(status)
        XCTAssertEqual(status.label, "Ideal range")
        XCTAssertEqual(app.staticTexts["nutrition.result.idealWeight"].label, "~4 kg / 8.82 lb")
        assertNutritionCalories("238 kcal/day")
    }

    func testNutritionUnderweightNeedsClinicalPlanEvenWithTarget() throws {
        app.tabBars.buttons["Nutrition"].tap()
        app.segmentedControls.buttons["kg"].tap()
        replaceNutritionText(app.textFields["nutrition.weight"], with: "10")
        assertNutritionCalories("551 kcal/day")

        let thin = app.buttons["nutrition.bcs.3"]
        scrollNutritionTo(thin, towardTop: true)
        thin.tap()
        let status = app.staticTexts["nutrition.result.status"]
        scrollNutritionTo(status)
        XCTAssertEqual(status.label, "Underweight")
        XCTAssertTrue(app.staticTexts["nutrition.result.idealUnavailable"].exists)
        let unavailable = app.staticTexts["nutrition.result.unavailable"]
        scrollNutritionTo(unavailable)
        XCTAssertFalse(app.staticTexts["nutrition.result.calories"].exists)

        let target = app.textFields["nutrition.clinicianTarget"]
        scrollNutritionTo(target, towardTop: true)
        replaceNutritionText(target, with: "12")
        let recordedTarget = app.staticTexts["nutrition.result.clinicianTarget"]
        scrollNutritionTo(recordedTarget)
        XCTAssertEqual(recordedTarget.label, "12 kg / 26.46 lb")
        scrollNutritionTo(unavailable)
        XCTAssertFalse(app.staticTexts["nutrition.result.calories"].exists)

        // Species changes must not turn an underweight patient's reference
        // target or target RER into an automatic calorie prescription.
        let cat = app.segmentedControls.buttons["Cat"]
        scrollNutritionTo(cat, towardTop: true)
        cat.tap()
        scrollNutritionTo(status)
        XCTAssertEqual(status.label, "Underweight")
        scrollNutritionTo(unavailable)
        XCTAssertFalse(app.staticTexts["nutrition.result.calories"].exists)
    }

    func testNutritionIntakeOverrideFloorAndRecovery() throws {
        app.tabBars.buttons["Nutrition"].tap()
        app.segmentedControls.buttons["kg"].tap()
        replaceNutritionText(app.textFields["nutrition.weight"], with: "12")
        let score = app.buttons["nutrition.bcs.7"]
        scrollNutritionTo(score)
        score.tap()
        assertNutritionCalories("315 kcal/day")

        let intake = app.textFields["nutrition.currentCalories"]
        scrollNutritionTo(intake, towardTop: true)
        replaceNutritionText(intake, with: "600")
        assertNutritionCalories("480 kcal/day")

        scrollNutritionTo(intake, towardTop: true)
        replaceNutritionText(intake, with: "100")
        scrollNutritionTo(app.staticTexts["nutrition.result.unavailable"])
        XCTAssertFalse(app.staticTexts["nutrition.result.calories"].exists,
                       "A below-floor intake must clear the previous calorie recommendation")
        let caution = app.staticTexts["nutrition.result.caution"]
        scrollNutritionTo(caution)
        XCTAssertTrue(caution.label.contains("60%"))

        scrollNutritionTo(intake, towardTop: true)
        replaceNutritionText(intake, with: "")
        assertNutritionCalories("315 kcal/day")
        XCTAssertFalse(app.staticTexts["nutrition.result.unavailable"].exists)
    }

    private func scrollNutritionTo(_ element: XCUIElement, towardTop: Bool = false,
                                   file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            if towardTop { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable,
                      "Nutrition control did not become visible: \(element)", file: file, line: line)
    }

    private func replaceNutritionText(_ field: XCUIElement, with text: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.isHittable, file: file, line: line)
        field.tap()
        let prior = field.value as? String ?? ""
        // An empty TextField reports its placeholder as value on some iOS
        // versions; only erase an actual numeric entry.
        if !prior.isEmpty && Double(prior) != nil {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count))
        }
        if !text.isEmpty { field.typeText(text) }
        let done = app.buttons["nutrition.keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), file: file, line: line)
        done.tap()
    }

    private func assertNutritionCalories(_ expected: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let calories = app.staticTexts["nutrition.result.calories"]
        scrollNutritionTo(calories, file: file, line: line)
        XCTAssertEqual(calories.label, expected, file: file, line: line)
    }

    func testInsulinStrengthMismatchCannotCalculate() throws {
        let search = app.textFields["Search medications…"]
        search.tap()
        search.typeText("Insulin glargine")
        let medication = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Insulin glargine (")).firstMatch
        XCTAssertTrue(medication.waitForExistence(timeout: 4))
        medication.tap()
        let weight = app.textFields["dose.sheet.weight"]
        weight.tap()
        weight.typeText("22.046226218")
        if app.buttons["dose.keyboard.done"].exists { app.buttons["dose.keyboard.done"].tap() }
        let concentration = app.textFields["dose.concentration"]
        for _ in 0..<10 where !concentration.isHittable { app.swipeUp() }
        concentration.tap()
        let prior = concentration.value as? String ?? "100"
        concentration.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count))
        concentration.typeText("300")
        let error = app.staticTexts["dose.concentration.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertTrue(error.label.contains("requires U-100"))
        XCTAssertFalse(app.buttons["dose.calculate"].isEnabled)
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

    func testPotassiumNeedsExplicitPrescription() throws {
        let search = app.textFields["Search medications…"]
        search.tap()
        search.typeText("potassium chloride")
        let medication = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Potassium chloride")).firstMatch
        XCTAssertTrue(medication.waitForExistence(timeout: 4))
        medication.tap()
        let weight = app.textFields["dose.sheet.weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 4))
        weight.tap()
        weight.typeText("22.046226218")
        app.buttons["dose.keyboard.done"].tap()
        let rate = app.textFields["dose.potassium.prescribed.rate"]
        for _ in 0..<8 where !rate.isHittable { app.swipeUp() }
        XCTAssertTrue(rate.exists)
        let calculate = app.buttons["dose.calculate"]
        for _ in 0..<3 where !calculate.isHittable { app.swipeUp() }
        XCTAssertFalse(calculate.isEnabled)
        for _ in 0..<3 where !rate.isHittable { app.swipeDown() }
        rate.tap()
        rate.typeText("0.6")
        app.buttons["dose.keyboard.done"].tap()
        for _ in 0..<3 where !calculate.isHittable { app.swipeUp() }
        XCTAssertFalse(calculate.isEnabled)
        for _ in 0..<3 where !rate.isHittable { app.swipeDown() }
        rate.tap()
        rate.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "0.1")
        app.buttons["dose.keyboard.done"].tap()
        for _ in 0..<3 where !calculate.isHittable { app.swipeUp() }
        XCTAssertTrue(calculate.isEnabled)
        calculate.tap()
        XCTAssertEqual(app.state, .runningForeground)
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "mEq/hr")).firstMatch
        for _ in 0..<4 where !result.exists { app.swipeUp() }
        XCTAssertTrue(result.exists)
        XCTAssertFalse(app.segmentedControls["dose.level"].exists)
    }
}
