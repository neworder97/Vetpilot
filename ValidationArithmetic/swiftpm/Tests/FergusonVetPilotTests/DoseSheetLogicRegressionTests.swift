import XCTest
@testable import FergusonVetPilot

// These execute extracted production view-logic bodies, NOT UIKit/SwiftUI screens.
final class DoseSheetLogicRegressionTests: XCTestCase {
    func testOintmentPlanCountsApplicationsWithoutInventingVolume() throws {
        let m = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Cyclosporine ophthalmic" })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "cyclosporine-ophthalmic-dog-1" })
        let p = DoseSheetLogicProbe(medication:m, protocolDefinition:preset.definition,
            selectedBuiltInPreset:preset, kg:0)
        XCTAssertNil(p.selectedAdministrationVolume)
        XCTAssertNil(p.selectedSolidPlan)
        XCTAssertTrue(p.supplySummary(days:7).contains("14 applications of 0.25-inch ointment strip"))
    }
    func testFixedWeightBandProtocolStillRequiresPatientWeight() throws {
        let m = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Mirtazapine oral" })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "mirtazapine-oral-dog-1" })
        let p = DoseSheetLogicProbe(medication:m, protocolDefinition:preset.definition,
            selectedBuiltInPreset:preset, kg:0, patientWeightOverride:"")
        XCTAssertNotNil(p.weightInputError)
        XCTAssertNil(p.administrationSelection)
    }
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
        XCTAssertTrue(p.supplySummary(days:7).contains("Quantity: 14 tablets"))
        p.selectedFrequency = .q12h
        XCTAssertEqual(try XCTUnwrap(p.selectedSolidPlan).roundedUnits,1)
        XCTAssertTrue(p.supplySummary(days:7).contains("Give 1 tablet PO q12 hours for 7 days"))
        XCTAssertTrue(p.supplySummary(days:7).contains("Quantity: 14 tablets"))
    }
    func testMethocarbamolRecognizesDailyAmountWording() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Methocarbamol" })
        let definition=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id=="methocarbamol-dog-1" }).definition
        var p=DoseSheetLogicProbe(medication:m,protocolDefinition:definition,kg:10)
        XCTAssertNil(p.administrationSelection)
        p.selectedFrequency = .q8h
        XCTAssertEqual(try XCTUnwrap(p.administrationSelection).selected,330,accuracy:1e-12)
    }
    func testInfusionVolumeNeedsVerifiedFinalConcentration() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.generic=="Potassium chloride" })
        let preset=try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id=="potassium-chloride-dog-1" })
        var p=DoseSheetLogicProbe(medication:m,protocolDefinition:preset.definition,selectedBuiltInPreset:preset,kg:10,concentration:"0.04")
        XCTAssertNotNil(p.concentrationInputError)
        XCTAssertNil(p.selectedAdministrationVolume)
        p.infusionConcentrationConfirmed=true
        XCTAssertNil(p.concentrationInputError)
        XCTAssertNotNil(p.prescribedRateInputError)
        XCTAssertNil(p.selectedAdministrationVolume)
        p.prescribedPotassiumRate = "0.1"
        XCTAssertNil(p.prescribedRateInputError)
        // Prescribed 0.1 mEq/kg/hr × 10 kg / 0.04 mEq/mL = 25 mL/hr.
        for level in DoseSelectionLevel.allCases {
            p.selectedDoseLevel = level
            XCTAssertEqual(try XCTUnwrap(p.selectedAdministrationVolume).value,25,accuracy:1e-12)
        }
        p.prescribedPotassiumRate = "0.50001"
        XCTAssertNotNil(p.prescribedRateInputError)
        XCTAssertNil(p.selectedAdministrationVolume)
        p.prescribedPotassiumRate = "0.1"
        XCTAssertTrue(try XCTUnwrap(p.administrationReviewReason).contains("High-risk"))
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
        XCTAssertTrue(p.supplySummary(days:7).contains("Quantity: 4 tablets"))
        p.selectedFrequency = .q12h
        XCTAssertFalse(p.canPlanSupply)
    }
    func testOnsiorRequiresReviewedPriorDosesAndThreeDayTotalLimit() throws {
        let m=try XCTUnwrap(ClinicalData.medications.first { $0.kind == .robenacoxibCatBand })
        var p=DoseSheetLogicProbe(medication:m,kg:4)
        XCTAssertTrue(p.supplySummary(days:2).contains("Blocked"))
        p.priorCourseHistoryConfirmed=true;p.priorCourseDoses=1
        XCTAssertTrue(p.supplySummary(days:2).contains("Quantity: 2 tablets"))
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

    func testReadableQuantityTracksDoseLevelAndStrength() throws {
        let med = Medication(generic:"Quantity fixture",brand:"",drugClass:"",species:[.dog],form:.tablet,indication:"Test only",kind:.mgKg,minDose:2,maxDose:6,frequency:"q12h",route:"PO",notes:"",source:"Test only",strengths:[10,20],concentration:nil,controlled:false)
        var p = DoseSheetLogicProbe(medication:med,kg:10)
        for (level, expected) in [(DoseSelectionLevel.low,"Nearest whole: 2 whole tablet(s)"),(.middle,"Nearest whole: 4 whole tablet(s)"),(.high,"Nearest whole: 6 whole tablet(s)")] {
            p.selectedDoseLevel = level
            let text = try XCTUnwrap(p.readableAdministrationSummary)
            XCTAssertTrue(text.hasPrefix(expected),text)
            XCTAssertTrue(text.contains("q12h"),text)
        }
        p.selectedStrengthIndex = 1
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("Nearest whole: 3 whole tablet(s)"))
    }
    func testReadableDailyTotalDividesBeforeDisplayingQuantity() throws {
        let med = Medication(generic:"Daily fixture",brand:"",drugClass:"",species:[.dog],form:.tablet,indication:"Test only",kind:.mgKg,minDose:4,maxDose:4,frequency:"q24h total daily dose",route:"PO",notes:"",source:"Test only",strengths:[20],concentration:nil,controlled:false)
        var p = DoseSheetLogicProbe(medication:med,kg:10)
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("Nearest whole: 2 whole tablet(s)"))
        p.selectedFrequency = .q12h
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("Nearest whole: 1 whole tablet(s)"))
    }
    func testReadableInjectionVolumeUsesSelectedDoseAndConcentration() throws {
        let med = Medication(generic:"Volume fixture",brand:"",drugClass:"",species:[.dog],form:.injection,indication:"Test only",kind:.mgKg,minDose:1,maxDose:3,frequency:"q12h",route:"SC",notes:"",source:"Test only",strengths:[],concentration:10,controlled:false)
        var p = DoseSheetLogicProbe(medication:med,kg:10,concentration:"10")
        for (level, expected) in [(DoseSelectionLevel.low,"1 mL"),(.middle,"2 mL"),(.high,"3 mL")] {
            p.selectedDoseLevel = level
            XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix(expected))
        }
        p.concentration = "20"
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("1.5 mL"))
        p.concentration = "0"
        XCTAssertNil(p.readableAdministrationSummary)
    }
    func testReadableCapsuleFractionDoesNotAuthorizeSplitting() throws {
        let med = Medication(generic:"Capsule fixture",brand:"",drugClass:"",species:[.dog],form:.capsule,indication:"Test only",kind:.mgKg,minDose:3,maxDose:3,frequency:"q12h",route:"PO",notes:"",source:"Test only",strengths:[20],concentration:nil,controlled:false)
        let p = DoseSheetLogicProbe(medication:med,kg:10)
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("Nearest whole: 2 whole capsule(s)"))
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).contains("1.5 capsule(s) equivalent"))
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationNote).contains("Do not split or open"))
    }
    func testReadableInfusionKeepsHourlyUnitsAndReviewWarning() throws {
        let med = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Potassium chloride" })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "potassium-chloride-dog-1" })
        var p = DoseSheetLogicProbe(medication:med,protocolDefinition:preset.definition,selectedBuiltInPreset:preset,kg:10,concentration:"0.04")
        p.infusionConcentrationConfirmed = true
        p.prescribedPotassiumRate = "0.1"
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("25 mL/hr continuous infusion"))
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationNote).contains("requires review"))
        p.prescribedPotassiumRate = "0.6"
        XCTAssertNil(p.readableAdministrationSummary)
    }
    func testAllSolidCatalogViewResultsFollowRoundingSelection() throws {
        var checked = 0
        for m in MedicationFormulations.organized where [.tablet,.capsule].contains(m.form) && m.generic != "Grapiprant" && m.generic != "Gabapentin" {
            for species in m.species {
                let presets = BuiltInProtocolCatalog.presets(for:m,species:species)
                let branches: [BuiltInProtocolPreset?] = (m.kind == .protocolOnly ? [] : [nil]) + presets.map { Optional($0) }
                for preset in branches {
                    let definition = preset.map { MedicationFormulations.definition($0.definition,for:m) }
                    var p = DoseSheetLogicProbe(medication:m,protocolDefinition:definition,selectedBuiltInPreset:preset,kg:10)
                    let indices = p.activeStrengths.isEmpty ? [0] : Array(p.activeStrengths.indices)
                    for index in indices {
                        p.selectedStrengthIndex = index
                        // User-entered test fixture only, never catalog dosing data.
                        if p.activeStrengths.isEmpty { p.manualStrength = "25" }
                        guard let target = p.administrationSelection, target.unit == "mg", let strength = p.selectedStrength, p.routeSupportsOralSolid else { continue }
                        let raw = target.selected / strength
                        let nearest = raw.rounded()
                        let input = abs(raw-nearest)<1e-12 ? nearest : raw
                        for (mode,expected) in [(SolidDoseRounding.down,floor(input)),(.nearest,input.rounded()),(.up,ceil(input)),(.down,floor(input))] {
                            p.solidRounding = mode
                            let plan = try XCTUnwrap(p.selectedSolidPlan,m.displayName)
                            XCTAssertEqual(plan.roundedUnits,expected,m.displayName)
                            XCTAssertEqual(plan.deliveredMg,expected * strength,accuracy:1e-10,m.displayName)
                            let label = try XCTUnwrap(p.readableAdministrationSummary,m.displayName)
                            XCTAssertTrue(label.hasPrefix(mode.rawValue + ": " + ClinicalData.format(expected) + " whole"),label)
                            XCTAssertTrue(label.contains("Exact mathematical quantity:"),label)
                            if !MedicationSafety.withinRange(plan.deliveredMg,target) {
                                XCTAssertFalse(p.supplySummary(days:7).hasPrefix("Give "),m.displayName)
                            }
                            checked += 1
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked,1000)
        print("SOLID_VIEW_ROUNDING_AUDIT: \(checked) production view result cases")
    }

    func testManualSolidStrengthRejectsInvalidValuesWithoutFallback() throws {
        let m = try XCTUnwrap(MedicationFormulations.organized.first { $0.generic == "Cisapride" })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for:m,species:.dog).first)
        var p = DoseSheetLogicProbe(medication:m,protocolDefinition:preset.definition,selectedBuiltInPreset:preset,kg:10)
        XCTAssertTrue(p.activeStrengths.isEmpty)
        XCTAssertNil(p.selectedSolidPlan)
        for value in ["0","-5","nan","inf","1,5"] {
            p.manualStrength = value
            XCTAssertNotNil(p.strengthInputError)
            XCTAssertNil(p.selectedSolidPlan)
            XCTAssertNil(p.readableAdministrationSummary)
        }
        p.manualStrength = "5"
        XCTAssertNil(p.strengthInputError)
        let raw = try XCTUnwrap(p.administrationSelection).selected / 5
        for mode in SolidDoseRounding.allCases {
            p.solidRounding = mode
            XCTAssertEqual(try XCTUnwrap(p.selectedSolidPlan).rawUnits,raw,accuracy:1e-12)
            XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix(mode.rawValue))
        }
    }

    func testExactMathPreservesFractionalAdministrationAndCourseArithmetic() throws {
        let m = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Carprofen" })
        var p = DoseSheetLogicProbe(medication:m,kg:10,solidRounding:.exact)
        XCTAssertTrue(try XCTUnwrap(p.readableAdministrationSummary).hasPrefix("Exact math: 1.76 tablet(s) equivalent"))
        XCTAssertTrue(p.supplySummary(days:7).contains("12.32"))
        XCTAssertFalse(p.supplySummary(days:7).hasPrefix("Give "))
        p.selectedFrequency = .q12h
        XCTAssertEqual(try XCTUnwrap(p.selectedSolidPlan).roundedUnits,0.88,accuracy:1e-12)
        XCTAssertTrue(p.supplySummary(days:7).contains("12.32"))
        p.solidRounding = .up
        XCTAssertTrue(p.supplySummary(days:7).contains("14 whole tablet(s)"))
        p.solidRounding = .exact
        XCTAssertTrue(p.supplySummary(days:7).contains("12.32"))
    }

}

