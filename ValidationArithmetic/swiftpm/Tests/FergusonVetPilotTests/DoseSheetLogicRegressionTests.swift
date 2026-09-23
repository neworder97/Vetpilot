import XCTest
@testable import FergusonVetPilot

// These execute extracted production view-logic bodies, NOT UIKit/SwiftUI screens.
final class DoseSheetLogicRegressionTests: XCTestCase {
    func testCarprofenOverrideDividesDailyTargetBeforeRounding() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Carprofen" })
        var p=DoseSheetLogicProbe(medication:m,kg:10)
        XCTAssertEqual(try XCTUnwrap(p.selectedSolidPlan).targetMg,44,accuracy:1e-12)
        p.selectedFrequency = .q12h
        let s=try XCTUnwrap(p.selectedSolidPlan)
        XCTAssertEqual(s.targetMg,22,accuracy:1e-12)
        XCTAssertTrue(p.administrationInstruction(for:s).contains("outside the selected dose range"))
        XCTAssertFalse(p.canPlanSupply)
    }
    func testSyntheticDailyTotalHasSameWeeklySupplyForOneOrTwoAdministrations() throws {
        let m=Medication(generic:"Arithmetic fixture",brand:"",drugClass:"",species:[.dog],form:.tablet,indication:"Test only",kind:.mgKg,minDose:4,maxDose:4,frequency:"q24h total daily dose",route:"PO",notes:"",source:"Test only",strengths:[20],concentration:nil,controlled:false)
        var p=DoseSheetLogicProbe(medication:m,kg:10)
        XCTAssertTrue(p.supplySummary(days:7).contains("quantity to dispense: 14"))
        p.selectedFrequency = .q12h
        XCTAssertEqual(try XCTUnwrap(p.selectedSolidPlan).roundedUnits,1)
        XCTAssertTrue(p.supplySummary(days:7).contains("quantity to dispense: 14"))
    }
    func testMethocarbamolRecognizesDailyAmountWording() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Methocarbamol" })
        let definition=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id=="methocarbamol-dog-1" }).definition
        var p=DoseSheetLogicProbe(medication:m,protocolDefinition:definition,kg:10)
        XCTAssertNil(p.administrationSelection)
        p.selectedFrequency = .q8h
        XCTAssertEqual(try XCTUnwrap(p.administrationSelection).selected,330,accuracy:1e-12)
    }
    func testInvalidConcentrationDoesNotFallbackInUIPath() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.brand=="Metacam maintenance" })
        for entry in ["", "0", "-5", "nan", "inf", "wrong", "1,5"] {
            let p=DoseSheetLogicProbe(medication:m,kg:10,concentration:entry)
            XCTAssertNil(p.activeConcentration,entry)
            XCTAssertNotNil(p.concentrationInputError,entry)
            XCTAssertNil(p.selectedAdministrationVolume,entry)
        }
        let p=DoseSheetLogicProbe(medication:m,kg:10,concentration:"1.5")
        XCTAssertEqual(try XCTUnwrap(p.selectedAdministrationVolume).value,2.0/3.0,accuracy:1e-12)
    }
    func testGalliprantUsesProductChartNotGenericWholeTabletRounding() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Grapiprant" })
        var p=DoseSheetLogicProbe(medication:m,kg:5)
        XCTAssertNil(p.selectedSolidPlan)
        XCTAssertEqual(try XCTUnwrap(p.galliprantPlan).units,0.5)
        XCTAssertTrue(p.supplySummary(days:7).contains("quantity to dispense: 4 whole tablets"))
        p.selectedFrequency = .q12h
        XCTAssertFalse(p.canPlanSupply)
    }
    func testOnsiorRequiresReviewedPriorDosesAndThreeDayTotalLimit() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.kind == .robenacoxibCatBand })
        var p=DoseSheetLogicProbe(medication:m,kg:4)
        XCTAssertTrue(p.supplySummary(days:2).contains("Blocked"))
        p.priorCourseHistoryConfirmed=true;p.priorCourseDoses=1
        XCTAssertTrue(p.supplySummary(days:2).contains("quantity to dispense: 2"))
        XCTAssertTrue(p.supplySummary(days:3).contains("Blocked"))
        XCTAssertTrue(p.supplySummary(days:30).contains("Blocked"))
        p.selectedFrequency = .q12h
        XCTAssertFalse(p.canPlanSupply)
    }
    func testAlternativeIntervalsDoNotProduceADispenseQuantity() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Enalapril" })
        var d=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.generic=="Enalapril" }).definition
        d.frequency="q12h, q24h"
        let p=DoseSheetLogicProbe(medication:m,protocolDefinition:d)
        XCTAssertNil(p.dosesPerDay);XCTAssertFalse(p.canPlanSupply)
    }
    func testMixedRouteDoesNotRecommendAnUnselectedFormulation() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Ondansetron" })
        var d=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id=="ondansetron-dog-1" }).definition
        // Explicit malformed clinic fixture: built-in ondansetron is now route-specific.
        d.route="PO/IV"
        let p=DoseSheetLogicProbe(medication:m,protocolDefinition:d,concentration:"2")
        XCTAssertTrue(try XCTUnwrap(p.administrationReviewReason).contains("Mixed oral/injectable"))
        XCTAssertFalse(p.canPlanSupply)
    }
    func testFelineEnrofloxacinCannotDoubleDailyCeilingByChangingFrequency() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Enrofloxacin" })
        let preset=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id=="enrofloxacin-cat-1" })
        let p=DoseSheetLogicProbe(medication:m,protocolDefinition:preset.definition,selectedBuiltInPreset:preset,kg:4,selectedFrequency:.q12h,selectedDoseLevel:.high)
        // Route-specific clinic selection permits evaluation of the daily limit.
        var oral = preset.definition
        oral.route = "PO"
        let selected=DoseSheetLogicProbe(medication:m,protocolDefinition:oral,selectedBuiltInPreset:preset,kg:4,selectedFrequency:.q12h,selectedDoseLevel:.high)
        XCTAssertTrue(try XCTUnwrap(selected.administrationReviewReason).contains("daily ceiling"))
        XCTAssertFalse(selected.canPlanSupply)
        XCTAssertFalse(p.canPlanSupply)
    }
    func testFurosemideDailyCeilingBlocksHighDoseAtQ8h() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Furosemide" })
        let preset=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id=="furosemide-dog-2" })
        let p=DoseSheetLogicProbe(medication:m,protocolDefinition:preset.definition,selectedBuiltInPreset:preset,kg:10,selectedFrequency:.q8h,selectedDoseLevel:.high)
        XCTAssertTrue(try XCTUnwrap(p.administrationReviewReason).contains("daily ceiling"))
        XCTAssertFalse(p.canPlanSupply)
    }
    func testAmbiguousOrNonfiniteWeightTextIsRejected() throws {
        let m = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Carprofen" })
        var p = DoseSheetLogicProbe(medication: m, kg: 10)
        for entry in ["1,000", "1,5", "nan", "inf", "0", "-1", ""] {
            p.patientWeightOverride = entry
            XCTAssertEqual(p.numericWeight, 0, entry)
            XCTAssertNotNil(p.weightInputError, entry)
        }
        p.patientWeightOverride = "10"
        XCTAssertEqual(p.numericWeight, 10)
        XCTAssertNil(p.weightInputError)
    }
}
