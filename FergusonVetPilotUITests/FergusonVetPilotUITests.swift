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

    private func selectTab(_ name: String) {
        if app.tabBars.buttons[name].exists { app.tabBars.buttons[name].tap() }
        else {
            app.tabBars.buttons["More"].tap()
            let item = app.staticTexts[name].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 4)); item.tap()
        }
    }

    func testLabworkSearchAndPreparation() throws {
        selectTab("Labwork")
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
        selectTab("Labwork")
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
        XCTAssertTrue(app.tabBars.buttons["My Clinic"].exists)
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
        for _ in 0..<12 where !calculate.isHittable { app.swipeUp() }
        XCTAssertTrue(calculate.waitForExistence(timeout: 3))
        XCTAssertTrue(calculate.isEnabled)
        for _ in 0..<12 where !calculate.isHittable { app.swipeUp() }
        calculate.tap()

        let doseResult = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "44 mg")).firstMatch
        XCTAssertTrue(doseResult.waitForExistence(timeout: 3))
        let quantity = app.staticTexts["dose.result.quantity"]
        for _ in 0..<4 where !quantity.exists { app.swipeUp() }
        XCTAssertTrue(quantity.exists)
        XCTAssertTrue(quantity.label.contains("tablet(s) equivalent"))


        for _ in 0..<20 where !sheetWeight.isHittable { app.swipeDown() }
        let q12 = app.buttons["dose.frequency.q12h"]
        // A partially clipped lazy-grid button can be reported as hittable.
        // Bring its center clear of the navigation bar before tapping.
        for _ in 0..<24 {
            if q12.exists && q12.isHittable && q12.frame.midY > 170 && q12.frame.midY < 680 { break }
            let up = !q12.exists || q12.frame.midY >= 680
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.72 : 0.4))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.4 : 0.72))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(q12.exists && q12.isHittable)
        XCTAssertGreaterThan(q12.frame.midY, 170)
        XCTAssertLessThan(q12.frame.midY, 680)
        q12.tap()

        let overrideWarning = app.staticTexts["dose.frequency.override.warning"]
        for _ in 0..<5 where !overrideWarning.isHittable { app.swipeUp() }
        XCTAssertTrue(overrideWarning.exists)

        for _ in 0..<12 where !calculate.isHittable { app.swipeUp() }
        calculate.tap()
        // This specific 25-mg strength cannot exactly deliver the fixed 22-mg
        // per-administration target. It must not become a dispense instruction.
        let blocked = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "outside the selected dose range")).firstMatch
        for _ in 0..<6 where !blocked.isHittable { app.swipeDown() }
        XCTAssertTrue(blocked.exists)
        XCTAssertFalse(app.buttons["dose.supply.7"].exists)

        app.buttons["dose.done"].tap()

        app.tabBars.buttons["My Clinic"].tap()
        XCTAssertTrue(app.navigationBars["My Clinic"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.tabBars.buttons["X-Ray"].exists)

        app.tabBars.buttons["Breeds"].tap()
        XCTAssertTrue(app.staticTexts["Breed predisposition library"].waitForExistence(timeout: 3))
        let breedSearch = app.textFields["Search breed or condition…"]
        XCTAssertTrue(breedSearch.waitForExistence(timeout: 3))
        breedSearch.tap()
        breedSearch.typeText("German")
        XCTAssertTrue(app.staticTexts["German Shepherd Dog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Hip/elbow dysplasia")).firstMatch.waitForExistence(timeout: 3))
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
        for _ in 0..<12 where !calculate.isHittable { app.swipeUp() }
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

        for _ in 0..<12 where !app.buttons["dose.calculate"].isHittable { app.swipeUp() }
        app.buttons["dose.calculate"].tap()
        let referenceRange = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "100–150 mg")).firstMatch
        for _ in 0..<8 where !referenceRange.exists { app.swipeUp() }
        XCTAssertTrue(referenceRange.waitForExistence(timeout: 3))
        sleep(2)

        app.buttons["dose.done"].tap()
        app.tabBars.buttons["My Clinic"].tap()
        XCTAssertTrue(app.navigationBars["My Clinic"].waitForExistence(timeout: 3))
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
        if app.buttons["dose.keyboard.done"].exists { app.buttons["dose.keyboard.done"].tap() }
        let calculate = app.buttons["dose.calculate"]
        for _ in 0..<12 where !calculate.exists { app.swipeUp() }
        XCTAssertTrue(calculate.exists)
        XCTAssertFalse(calculate.isEnabled)
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
        for _ in 0..<12 where !calculate.isHittable { app.swipeUp() }
        calculate.tap()
        XCTAssertEqual(app.state, .runningForeground)
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "mEq/hr")).firstMatch
        for _ in 0..<4 where !result.exists { app.swipeUp() }
        XCTAssertTrue(result.exists)
        XCTAssertFalse(app.segmentedControls["dose.level"].exists)
    }
    func testMedicationInputsPrecedeCalculateAndSelectionsSurvive() throws {
        let search = app.textFields["Search medications…"]
        search.tap(); search.typeText("Cefpodoxime")
        let med = app.staticTexts["Cefpodoxime proxetil (Simplicef)"]
        XCTAssertTrue(med.waitForExistence(timeout: 4)); med.tap()
        app.segmentedControls.buttons["kg"].tap()
        let weight = app.textFields["dose.sheet.weight"]
        weight.tap(); weight.typeText("10")
        app.buttons["dose.keyboard.done"].tap()
        let level = app.segmentedControls["dose.level"]
        for _ in 0..<8 where !level.isHittable { app.swipeUp() }
        XCTAssertTrue(level.exists)
        level.buttons["High"].tap()
        let frequency = app.buttons["dose.frequency.recommended"]
        for _ in 0..<8 where !frequency.isHittable { app.swipeUp() }
        XCTAssertTrue(frequency.exists)
        let days = app.buttons["dose.supply.7"]
        for _ in 0..<8 where !days.isHittable { app.swipeUp() }
        XCTAssertTrue(days.exists); days.tap()
        XCTAssertFalse(app.staticTexts["dose.candidate.amount"].exists)
        let calculate = app.buttons["dose.calculate"]
        for _ in 0..<8 where !calculate.isHittable { app.swipeUp() }
        calculate.tap()
        let amount = app.staticTexts["dose.candidate.amount"]
        for _ in 0..<8 where !amount.isHittable { app.swipeUp() }
        XCTAssertTrue(amount.label.contains("100 mg"))
        let quantity = app.staticTexts["dose.result.quantity"]
        XCTAssertTrue(quantity.label.contains("1 tablet(s)"))
        let supply = app.staticTexts["dose.supply.summary"]
        for _ in 0..<8 where !supply.isHittable { app.swipeUp() }
        XCTAssertTrue(supply.label.contains("quantity to dispense: 7"))
        let candidateShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        candidateShot.name = "Medication-candidate-first"; candidateShot.lifetime = .keepAlways; add(candidateShot)
        // A changed weight must clear the old calculated candidate, not show stale math.
        for _ in 0..<16 where !weight.isHittable { app.swipeDown() }
        weight.tap(); weight.typeText("0")
        app.buttons["dose.keyboard.done"].tap()
        XCTAssertFalse(app.staticTexts["dose.candidate.amount"].exists)
    }

    func testMyClinicCreateSearchFavoriteChecklistAndShare() throws {
        app.tabBars.buttons["My Clinic"].tap()
        XCTAssertFalse(app.tabBars.buttons["X-Ray"].exists)
        app.buttons["clinic.new"].tap()
        let title = "Exam kit " + UUID().uuidString.prefix(6)
        let titleField = app.textFields["clinic.editor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 4))
        titleField.tap(); titleField.typeText(title)
        app.buttons["clinic.keyboard.done"].tap()
        app.buttons["clinic.editor.add.step"].tap()
        let step = app.descendants(matching: .any).matching(identifier: "clinic.editor.step").firstMatch
        step.tap(); step.typeText("Check room supplies")
        app.buttons["clinic.keyboard.done"].tap()
        let equipmentButton = app.buttons["clinic.editor.add.equipment"]
        for _ in 0..<8 where !equipmentButton.isHittable { app.swipeUp() }
        equipmentButton.tap()
        let equipment = app.textFields["clinic.editor.equipment"].firstMatch
        for _ in 0..<6 where !equipment.isHittable { app.swipeUp() }
        equipment.tap(); equipment.typeText("Stethoscope")
        app.buttons["clinic.keyboard.done"].tap()
        app.buttons["clinic.editor.save"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 4)); search.tap(); search.typeText(title)
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        let row = app.buttons["clinic.item." + title]
        XCTAssertTrue(row.waitForExistence(timeout: 4)); row.tap()
        let check = app.buttons["1. Check room supplies"]
        XCTAssertTrue(check.waitForExistence(timeout: 4)); check.tap()
        XCTAssertEqual(check.value as? String, "Checked")
        app.buttons["clinic.favorite"].tap()
        let pdf = app.buttons["clinic.share.pdf"]
        for _ in 0..<16 where !pdf.isHittable { app.swipeUp() }
        XCTAssertTrue(pdf.exists)
        pdf.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["Save to Files"].exists)
        let shareShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shareShot.name = "MyClinic-PDF-share-sheet"; shareShot.lifetime = .keepAlways; add(shareShot)
        // Persistence survives a normal app restart.
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 8))
        app.tabBars.buttons["My Clinic"].tap()
        app.segmentedControls.buttons["Favorites"].tap()
        let saved = app.buttons["clinic.item." + title]
        XCTAssertTrue(saved.waitForExistence(timeout: 4)); saved.tap()
        XCTAssertEqual(app.buttons["1. Check room supplies"].value as? String, "Not checked")
        let editable = app.buttons["clinic.share.file"]
        for _ in 0..<16 where !editable.isHittable { app.swipeUp() }
        XCTAssertTrue(editable.exists); editable.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["Save to Files"].exists)
    }

    func testSharingSettingsPersistRecipients() throws {
        app.tabBars.buttons["My Clinic"].tap()
        let settings = app.buttons["clinic.sharing.settings"]
        for _ in 0..<12 where !settings.isHittable { app.swipeUp() }
        settings.tap()
        let email = app.textFields["clinic.email.recipient"]
        for _ in 0..<8 where !email.isHittable { app.swipeUp() }
        email.tap()
        if let old = email.value as? String, old.contains("@") {
            email.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        email.typeText("review@example.com")
        app.swipeUp()
        let phone = app.textFields["clinic.text.recipient"]
        for _ in 0..<8 where !phone.isHittable { app.swipeUp() }
        phone.tap()
        if let old = phone.value as? String, old.contains("555") {
            phone.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        phone.typeText("2125550100")
        app.navigationBars.buttons["Done"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 10))
        app.tabBars.buttons["My Clinic"].tap()
        XCTAssertTrue(app.navigationBars["My Clinic"].waitForExistence(timeout: 5))
        for _ in 0..<12 where !settings.isHittable { app.swipeUp() }
        settings.tap()
        for _ in 0..<8 where !email.isHittable { app.swipeUp() }
        XCTAssertEqual(email.value as? String, "review@example.com")
        for _ in 0..<8 where !phone.isHittable { app.swipeUp() }
        XCTAssertEqual(phone.value as? String, "2125550100")
    }

    func testEmailAndTextExportOfferShareFallbackOnSimulator() throws {
        app.tabBars.buttons["My Clinic"].tap()
        app.buttons["clinic.new"].tap()
        let titleField = app.textFields["clinic.editor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 4))
        titleField.tap(); titleField.typeText("Export fallback " + UUID().uuidString.prefix(6))
        app.buttons["clinic.keyboard.done"].tap()
        app.buttons["clinic.editor.save"].tap()
        let email = app.buttons["clinic.email.pdf"]
        for _ in 0..<16 where !email.isHittable { app.swipeUp() }
        email.tap()
        XCTAssertTrue(app.alerts["Email setup needed"].waitForExistence(timeout: 5))
        app.alerts.buttons["Choose email app"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["Save to Files"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Automatic dose calculator"].waitForExistence(timeout: 10))
        app.tabBars.buttons["My Clinic"].tap()
        XCTAssertTrue(app.navigationBars["My Clinic"].waitForExistence(timeout: 5))
        let text = app.buttons["clinic.text.file"]
        for _ in 0..<16 where !text.isHittable { app.swipeUp() }
        text.tap()
        XCTAssertTrue(app.alerts["Messages setup needed"].waitForExistence(timeout: 5))
        app.alerts.buttons["Choose sharing app"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["Save to Files"].exists)
    }

}
