import XCTest
@testable import FergusonVetPilot

final class MedicationSafetyRegressionTests: XCTestCase {
    func testBuprenorphineProductSpecificProtocolsRejectSubstitution() throws {
        for id in ["buprenorphine-cat-4", "buprenorphine-cat-1", "buprenorphine-dog-1"] {
            let p = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == id })
            for strength in [0.3, 1.8, 20.0] {
                let result = ProtocolDoseCalculator.calculate(definition: p.definition,
                    kg: 4, strength: nil, concentration: strength)
                XCTAssertEqual(result.available, strength == p.concentration, id)
                if !result.available { XCTAssertTrue(result.formulation.isEmpty) }
            }
        }
    }
    func testDigoxinWeightBandsAndMaximumAmount() throws {
        for (id, kg, allowed) in [
            ("digoxin-cat-1", 2.999, true), ("digoxin-cat-1", 3.0, false),
            ("digoxin-cat-2", 0.0, false), ("digoxin-cat-2", 2.999, false),
            ("digoxin-cat-2", 3.0, true), ("digoxin-cat-2", 6.0, true),
            ("digoxin-cat-2", 6.001, false), ("digoxin-cat-3", 6.0, false),
            ("digoxin-cat-3", 6.001, true)
        ] {
            let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == id })
            let result = ProtocolDoseCalculator.calculate(definition: preset.definition,
                kg: kg, strength: nil, concentration: nil, builtInPreset: preset)
            XCTAssertEqual(result.available, allowed, id)
            XCTAssertEqual(AdministrationMath.selection(for: preset.definition, kg: kg, level: .high) != nil, allowed, id)
            if !allowed { XCTAssertTrue(result.formulation.isEmpty) }
        }
        let dog = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "digoxin-dog-1" })
        let selected = try XCTUnwrap(AdministrationMath.selection(for: dog.definition, kg: 60, level: .high))
        XCTAssertEqual(selected.low, 0.15, accuracy: 1e-12)
        XCTAssertEqual(selected.high, 0.25, accuracy: 1e-12)
        XCTAssertEqual(selected.selected, 0.25, accuracy: 1e-12)
        let capped = ProtocolDoseCalculator.calculate(definition: dog.definition, kg: 60,
            strength: nil, concentration: nil, builtInPreset: dog)
        XCTAssertTrue(capped.headline.hasPrefix("0.15–0.25 mg"))
        XCTAssertNil(AdministrationMath.selection(for: dog.definition, kg: 101, level: .low))
    }

    func testOralAndIVAntiemeticBranchesRemainSeparate() throws {
        for species in ["dog", "cat"] {
            let oral = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "ondansetron-\(species)-1" })
            let iv = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "ondansetron-\(species)-2" })
            XCTAssertEqual(oral.route, "PO")
            XCTAssertEqual(oral.frequency, "q12–24h")
            XCTAssertNil(oral.concentration)
            XCTAssertEqual(iv.route, "IV")
            XCTAssertTrue(iv.strengths.isEmpty)
            let dose = try XCTUnwrap(AdministrationMath.selection(for: iv.definition, kg: 10, level: .high))
            let volume = try XCTUnwrap(AdministrationMath.volume(selection: dose, basis: iv.doseBasis, concentration: 2))
            XCTAssertEqual(dose.selected, 1.5, accuracy: 1e-12)
            XCTAssertEqual(volume.value, 0.75, accuracy: 1e-12)
        }
    }

    func testInsulinProtocolsRejectDifferentProductConcentrations() throws {
        let insulin = BuiltInProtocolCatalog.all.filter { $0.id.hasPrefix("insulin-") }
        XCTAssertEqual(insulin.count, 6)
        for preset in insulin {
            let expected = try XCTUnwrap(preset.concentration)
            let valid = ProtocolDoseCalculator.calculate(definition: preset.definition,
                kg: 10, strength: nil, concentration: expected, builtInPreset: preset)
            XCTAssertTrue(valid.available, preset.id)
            for wrong in [20.0, 40, 100, 200, 300] where wrong != expected {
                let invalid = ProtocolDoseCalculator.calculate(definition: preset.definition,
                    kg: 10, strength: nil, concentration: wrong, builtInPreset: preset)
                XCTAssertFalse(invalid.available, preset.id)
                let withoutMetadata = ProtocolDoseCalculator.calculate(definition: preset.definition,
                    kg: 10, strength: nil, concentration: wrong)
                XCTAssertFalse(withoutMetadata.available, "Insulin guard must also use the stable definition key: \(preset.id)")
                XCTAssertEqual(invalid.headline, "Insulin product mismatch")
                XCTAssertTrue(invalid.formulation.isEmpty)
            }
            XCTAssertNotNil(MedicationSafety.insulinConcentrationIssue(presetID: preset.id, concentration: nil))
        }
        XCTAssertNil(MedicationSafety.insulinConcentrationIssue(presetID: "furosemide-dog-1", concentration: 10))
    }

    func testClonidineFloatingBoundaryDoesNotAddATablet() throws {
        let p = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 6 * 0.05, strengthMg: 0.3, rounding: .up))
        XCTAssertEqual(p.roundedUnits, 1)
    }
    func testFludrocortisoneFloatingBoundaryDoesNotDropATablet() throws {
        let p = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 60 * 0.02, strengthMg: 0.1, rounding: .down))
        XCTAssertEqual(p.roundedUnits, 12)
    }
    func testRealFractionsAreNotSnapped() throws {
        XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 1.000000001, strengthMg: 1, rounding: .up)).roundedUnits, 2)
        XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 0.999999999, strengthMg: 1, rounding: .down)).roundedUnits, 0)
    }
    func testConcentrationsAndSmallDosesRoundTripForEveryPreset() throws {
        for p in BuiltInProtocolCatalog.all {
            for value in [p.minDose,p.maxDose] + p.strengths + (p.concentration.map { [$0] } ?? []) {
                XCTAssertEqual(try XCTUnwrap(Double(MedicationSafety.input(value))), value, p.id)
            }
        }
        XCTAssertEqual(MedicationSafety.input(0.0025), "0.0025")
        XCTAssertEqual(ClinicalData.format(0.0004), "0.0004")
        XCTAssertEqual(ClinicalData.format(0.0025), "0.0025")
    }
    func testNonzeroDisplayNeverBecomesZero() throws {
        for v in [1e-300,1e-30,1e-10,0.00001,0.0004,0.0005,0.0025,0.0075,0.011] {
            XCTAssertGreaterThan(try XCTUnwrap(Double(ClinicalData.format(v))), 0)
        }
    }
    func testInvalidConcentrationStringsAreRejected() {
        for s in ["", " ", "0", "-5", "nan", "inf", "1e400", "1,5", "1,000", "wrong"] {
            XCTAssertNil(MedicationSafety.parsePositive(s),s)
        }
        XCTAssertEqual(MedicationSafety.parsePositive(" 1.5 "),1.5)
    }
    func testEditorValidationRejectsMalformedUpperBoundsAndStrengths() {
        XCTAssertTrue(MedicationSafety.enteredRangeIsValid(low:"0.0025", high:"0.005", concentration:"0.05"))
        for high in ["-1","0","1","nan","wrong"] {
            XCTAssertFalse(MedicationSafety.enteredRangeIsValid(low:"2", high:high, concentration:""))
        }
        XCTAssertFalse(MedicationSafety.enteredRangeIsValid(low:"1", high:"2", concentration:"1,5"))
    }
    func testInvalidProtocolDefinitionsDoNotDefaultToMgKgOrDog() throws {
        var p = try XCTUnwrap(BuiltInProtocolCatalog.all.first).definition
        p.doseBasisRaw = "Unknown basis"
        XCTAssertFalse(ProtocolDoseCalculator.calculate(definition:p,kg:10,strength:nil,concentration:nil).available)
        XCTAssertNil(AdministrationMath.selection(for:p,kg:10,level:.middle))
        p = try XCTUnwrap(BuiltInProtocolCatalog.all.first).definition
        p.speciesRaw = "Unknown species"
        XCTAssertFalse(ProtocolDoseCalculator.calculate(definition:p,kg:10,strength:nil,concentration:nil).available)
    }
    func testNegativeReversedAndNonfiniteDoseRangesAreRejected() throws {
        for (lo,hi) in [(-5.0,-1.0),(10,1),(Double.infinity,Double.infinity),(1,Double.nan)] {
            var p = try XCTUnwrap(BuiltInProtocolCatalog.all.first).definition;p.minDose=lo;p.maxDose=hi
            XCTAssertFalse(ProtocolDoseCalculator.calculate(definition:p,kg:10,strength:nil,concentration:nil).available)
            XCTAssertNil(AdministrationMath.selection(for:p,kg:10,level:.high))
        }
    }
    func testInvalidWeightsAreRejectedByBothCalculatorsAndHelpers() throws {
        let p = try XCTUnwrap(BuiltInProtocolCatalog.all.first).definition
        let m = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Carprofen" })
        for v in [0,-1,Double.nan,Double.infinity,-Double.infinity] {
            XCTAssertFalse(ProtocolDoseCalculator.calculate(definition:p,kg:v,strength:nil,concentration:nil).available)
            XCTAssertFalse(ClinicalData.calculate(medication:m,kg:v,strength:25,concentration:nil).available)
            XCTAssertNil(AdministrationMath.selection(for:p,kg:v,level:.middle))
        }
    }
    func testOverflowDoesNotProduceAnAvailableDose() throws {
        let p = try XCTUnwrap(BuiltInProtocolCatalog.all.first).definition
        XCTAssertFalse(ProtocolDoseCalculator.calculate(definition:p,kg:Double.greatestFiniteMagnitude,strength:nil,concentration:nil).available)
        XCTAssertNil(AdministrationMath.selection(for:p,kg:Double.greatestFiniteMagnitude,level:.high))
    }
    func testInvalidExplicitConcentrationsNeverUseDefault() throws {
        let m = try XCTUnwrap(ClinicalData.medications.first { $0.brand == "Metacam maintenance" })
        for v in [0,-1,Double.nan,Double.infinity] {
            XCTAssertFalse(ClinicalData.calculate(medication:m,kg:10,strength:nil,concentration:v).available)
        }
        let p = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.concentration != nil }).definition
        for v in [0,-1,Double.nan,Double.infinity] {
            XCTAssertFalse(ProtocolDoseCalculator.calculate(definition:p,kg:10,strength:nil,concentration:v).available)
        }
    }
    func testInvalidSolidAndSupplyValuesCannotTrap() {
        for v in [0,-1,Double.nan,Double.infinity] {
            XCTAssertNil(AdministrationMath.solidPlan(targetMg:v,strengthMg:25,rounding:.up))
            XCTAssertNil(AdministrationMath.solidPlan(targetMg:10,strengthMg:v,rounding:.up))
            XCTAssertEqual(AdministrationMath.administrations(days:7,dosesPerDay:v),0)
        }
        XCTAssertEqual(AdministrationMath.administrations(days:Int.max,dosesPerDay:6),0)
    }
    func testDailyTotalIsDividedBeforeRounding() throws {
        let s = DoseRangeSelection(low:44,high:44,selected:44,unit:"mg",math:"test",isRate:false)
        for (n,expected) in [(1.0,44.0),(2,22),(3,44.0/3.0)] {
            let p=try XCTUnwrap(MedicationSafety.perAdministration(s,frequency:"q24h total daily dose",dosesPerDay:n))
            XCTAssertEqual(p.selected,expected,accuracy:1e-12)
            XCTAssertEqual(p.selected*n,44,accuracy:1e-12)
        }
        XCTAssertNil(MedicationSafety.perAdministration(s,frequency:"total daily dose",dosesPerDay:nil))
    }
    func testMethocarbamolDailyWordingIsRecognized() throws {
        let p = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "methocarbamol-dog-1" })
        let s = try XCTUnwrap(AdministrationMath.selection(for:p.definition,kg:10,level:.middle))
        XCTAssertTrue(MedicationSafety.dailyTotal(p.frequency))
        XCTAssertEqual(try XCTUnwrap(MedicationSafety.perAdministration(s,frequency:p.frequency,dosesPerDay:3)).selected,330,accuracy:1e-12)
    }
    func testAlternativeSchedulesAreNotSilentlyParsed() {
        for s in ["q12h, q24h", "q8h, q8-12h", "q12-24h, q12h", "q6h as needed", "q24h initially; taper by response", "total per week; divide per monitored protocol", "once", "q12h during loading phase"] {
            XCTAssertNil(MedicationSafety.regularDosesPerDay(s),s)
        }
        XCTAssertEqual(MedicationSafety.regularDosesPerDay("q12h"),2)
        XCTAssertEqual(MedicationSafety.regularDosesPerDay("q24h total daily dose; may divide q12h"),1)
        XCTAssertEqual(MedicationSafety.regularDosesPerDay("total daily dose divided into 2 portions ~12h apart"),2)
    }
    func testDurationCapsAreReadWithoutExtendingTheCourse() {
        XCTAssertEqual(MedicationSafety.documentedDaysCeiling("q24h up to 3 days"),3)
        XCTAssertEqual(MedicationSafety.documentedDaysCeiling("q12h for 5 days"),5)
        XCTAssertEqual(MedicationSafety.documentedDaysCeiling("q12h for up to 14 days"),14)
        XCTAssertNil(MedicationSafety.documentedDaysCeiling("q24h"))
    }
    func testGalliprantChartUsesHalfOfTwentyMgForFiveKg() throws {
        let p=try XCTUnwrap(MedicationSafety.galliprantPlan(weight:5,unit:"kg"))
        XCTAssertEqual(p.strengthMg,20);XCTAssertEqual(p.units,0.5);XCTAssertEqual(p.deliveredMg,10)
    }
    func testGalliprantPrintedBandsAndBoundaryGaps() throws {
        for (w,strength,units) in [(3.6,20.0,0.5),(6.8,20,0.5),(6.9,20,1),(13.6,20,1),(13.7,60,0.5),(20.4,60,0.5),(20.5,60,1),(34,60,1),(34.1,100,1),(68,100,1)] {
            let p=try XCTUnwrap(MedicationSafety.galliprantPlan(weight:w,unit:"kg"));XCTAssertEqual(p.strengthMg,strength);XCTAssertEqual(p.units,units)
        }
        for w in [3.5,6.85,13.65,20.45,34.05,68.1] { XCTAssertNil(MedicationSafety.galliprantPlan(weight:w,unit:"kg")) }
        XCTAssertEqual(MedicationSafety.galliprantPlan(weight:15.1,unit:"lb")?.units,1)
        XCTAssertNil(MedicationSafety.galliprantPlan(weight:5,unit:"stones"))
    }
    func testUnapprovedProtocolsCannotFeedAdministration() throws {
        var p=try XCTUnwrap(BuiltInProtocolCatalog.all.first).definition;p.veterinarianApproved=false
        XCTAssertNil(AdministrationMath.selection(for:p,kg:10,level:.middle))
    }
    func testInvalidCustomSavedDefinitionIsNotAnAutomaticCalculator() {
        let d=CustomMedicationDefinition(generic:"Test",brand:"",drugClass:"",speciesRaw:"Dog",formRaw:"Tablet",indication:"",doseBasisRaw:"BROKEN",minDose:1,maxDose:2,frequency:"q12h",route:"PO",concentration:nil,sourceReference:"test",notes:"")
        XCTAssertEqual(d.asMedication.kind,.protocolOnly)
    }
}
