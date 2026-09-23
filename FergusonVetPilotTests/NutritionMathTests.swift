import XCTest
@testable import FergusonVetPilot

final class NutritionMathTests: XCTestCase {
    // Fixed reference values for PNA's public adult-pet calculator, inspected
    // 2026-09-23: https://petnutritionalliance.org/resources/calorie-calculator/
    // Production calculator JS SHA-256:
    // 9bd2de3061fecf057dacfa6d3f8a9c2127ab35df0b4897da3f5046a4b9dd35a9
    // Expected values are constants, never derived through NutritionMath.
    private struct ReferenceCase {
        let species: Species
        let unit: NutritionWeightUnit
        let bcs: Int
        let ideal: Double
        let baselineNeutered: Double
        let baselineIntact: Double
        let targetNeutered: Double
        let targetIntact: Double
        let floor: Double
    }

    private let referenceCases: [ReferenceCase] = [
        .init(species: .dog, unit: .kg, bcs: 5, ideal: 10, baselineNeutered: 551, baselineIntact: 630, targetNeutered: 551, targetIntact: 630, floor: 236),
        .init(species: .dog, unit: .kg, bcs: 6, ideal: 9.1, baselineNeutered: 367, baselineIntact: 367, targetNeutered: 330, targetIntact: 330, floor: 220),
        .init(species: .dog, unit: .kg, bcs: 7, ideal: 8.3, baselineNeutered: 342, baselineIntact: 342, targetNeutered: 274, targetIntact: 274, floor: 205),
        .init(species: .dog, unit: .kg, bcs: 8, ideal: 7.7, baselineNeutered: 324, baselineIntact: 324, targetNeutered: 259, targetIntact: 259, floor: 194),
        .init(species: .dog, unit: .kg, bcs: 9, ideal: 7.1, baselineNeutered: 304, baselineIntact: 304, targetNeutered: 243, targetIntact: 243, floor: 183),
        .init(species: .cat, unit: .kg, bcs: 4, ideal: 10.5, baselineNeutered: 408, baselineIntact: 408, targetNeutered: 408, targetIntact: 408, floor: 245),
        .init(species: .cat, unit: .kg, bcs: 5, ideal: 10, baselineNeutered: 472, baselineIntact: 551, targetNeutered: 472, targetIntact: 551, floor: 236),
        .init(species: .cat, unit: .kg, bcs: 6, ideal: 9.1, baselineNeutered: 367, baselineIntact: 367, targetNeutered: 330, targetIntact: 330, floor: 220),
        .init(species: .cat, unit: .kg, bcs: 7, ideal: 8.3, baselineNeutered: 342, baselineIntact: 342, targetNeutered: 274, targetIntact: 274, floor: 205),
        .init(species: .cat, unit: .kg, bcs: 8, ideal: 7.7, baselineNeutered: 324, baselineIntact: 324, targetNeutered: 259, targetIntact: 259, floor: 194),
        .init(species: .cat, unit: .kg, bcs: 9, ideal: 7.1, baselineNeutered: 304, baselineIntact: 304, targetNeutered: 243, targetIntact: 243, floor: 183),
        .init(species: .dog, unit: .lb, bcs: 5, ideal: 20, baselineNeutered: 512, baselineIntact: 585, targetNeutered: 512, targetIntact: 585, floor: 220),
        .init(species: .dog, unit: .lb, bcs: 6, ideal: 18.2, baselineNeutered: 341, baselineIntact: 341, targetNeutered: 307, targetIntact: 307, floor: 205),
        .init(species: .dog, unit: .lb, bcs: 7, ideal: 16.7, baselineNeutered: 320, baselineIntact: 320, targetNeutered: 256, targetIntact: 256, floor: 192),
        .init(species: .dog, unit: .lb, bcs: 8, ideal: 15.4, baselineNeutered: 301, baselineIntact: 301, targetNeutered: 241, targetIntact: 241, floor: 180),
        .init(species: .dog, unit: .lb, bcs: 9, ideal: 14.3, baselineNeutered: 284, baselineIntact: 284, targetNeutered: 227, targetIntact: 227, floor: 171),
        .init(species: .cat, unit: .lb, bcs: 4, ideal: 21, baselineNeutered: 379, baselineIntact: 379, targetNeutered: 379, targetIntact: 379, floor: 228),
        .init(species: .cat, unit: .lb, bcs: 5, ideal: 20, baselineNeutered: 439, baselineIntact: 512, targetNeutered: 439, targetIntact: 512, floor: 220),
        .init(species: .cat, unit: .lb, bcs: 6, ideal: 18.2, baselineNeutered: 341, baselineIntact: 341, targetNeutered: 307, targetIntact: 307, floor: 205),
        .init(species: .cat, unit: .lb, bcs: 7, ideal: 16.7, baselineNeutered: 320, baselineIntact: 320, targetNeutered: 256, targetIntact: 256, floor: 192),
        .init(species: .cat, unit: .lb, bcs: 8, ideal: 15.4, baselineNeutered: 301, baselineIntact: 301, targetNeutered: 241, targetIntact: 241, floor: 180),
        .init(species: .cat, unit: .lb, bcs: 9, ideal: 14.3, baselineNeutered: 284, baselineIntact: 284, targetNeutered: 227, targetIntact: 227, floor: 171)
    ]

    func testPNAReferenceCasesAcrossSpeciesUnitsBCSAndReproductiveStatus() throws {
        for reference in referenceCases {
            for status in NutritionReproductiveStatus.allCases {
                let result = try XCTUnwrap(NutritionMath.estimate(
                    species: reference.species,
                    weight: reference.unit == .kg ? 10 : 20,
                    unit: reference.unit,
                    bcs: reference.bcs,
                    reproductiveStatus: status
                ))
                let label = "\(reference.species) \(reference.unit) BCS \(reference.bcs) \(status)"
                let expectedIdealKg = reference.unit == .lb ? reference.ideal / 2.205 : reference.ideal
                XCTAssertEqual(try XCTUnwrap(result.estimatedIdealKg), expectedIdealKg, accuracy: 1e-10, label)
                XCTAssertEqual(result.baselineCalories, status == .intact ? reference.baselineIntact : reference.baselineNeutered, label)
                XCTAssertEqual(result.targetCalories, status == .intact ? reference.targetIntact : reference.targetNeutered, label)
                XCTAssertEqual(result.calorieFloor, reference.floor, label)
                XCTAssertEqual(result.reproductiveStatus, status)
                XCTAssertEqual(result.reductionPercent, reference.bcs >= 7 ? 20 : (reference.bcs == 6 ? 10 : 0))
            }
        }
    }

    func testRERUsesMetabolicWeightEquation() {
        XCTAssertEqual(NutritionMath.rer(kg: 10), 393.6389276, accuracy: 0.0001)
    }

    func testDogThirtyKilogramsBCSSevenMatchesPNA() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 30, unit: .kg, bcs: 7, reproductiveStatus: .spayedNeutered))
        XCTAssertEqual(result.estimatedIdealKg, 25)
        XCTAssertEqual(try XCTUnwrap(result.planningRER), 782.6237921, accuracy: 0.0001)
        XCTAssertEqual(result.baselineCalories, 783)
        XCTAssertEqual(result.targetCalories, 626)
        XCTAssertEqual(result.calorieFloor, 470)
        XCTAssertEqual(result.goal, .lose)
    }

    func testCatSixKilogramsBCSSevenMatchesPNA() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .cat, weight: 6, unit: .kg, bcs: 7, reproductiveStatus: .intact))
        XCTAssertEqual(result.estimatedIdealKg, 5)
        XCTAssertEqual(result.baselineCalories, 234)
        XCTAssertEqual(result.targetCalories, 187)
        XCTAssertEqual(result.calorieFloor, 140)
    }

    func testBCSFourCatUsesPNASpecialIdealWeightWithoutMaintenanceMultiplier() throws {
        for status in NutritionReproductiveStatus.allCases {
            let result = try XCTUnwrap(NutritionMath.estimate(species: .cat, weight: 4, unit: .kg, bcs: 4, reproductiveStatus: status))
            XCTAssertEqual(result.estimatedIdealKg, 4.2)
            XCTAssertEqual(result.targetCalories, 205)
            XCTAssertEqual(result.calorieFloor, 123)
            XCTAssertEqual(result.weightStatus, "Ideal range")
            XCTAssertTrue(result.caution.contains("105%"))
        }
    }

    func testBCSFiveDoesNotRoundEnteredWeightBeforeCalculating() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 10.04, unit: .kg, bcs: 5, reproductiveStatus: .spayedNeutered))
        XCTAssertEqual(result.estimatedIdealKg, 10.04)
        XCTAssertEqual(result.targetCalories, 553)
    }

    func testIdealWeightHalfTieRoundsUpBeforeCalorieCalculation() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 24.3, unit: .kg, bcs: 7, reproductiveStatus: .spayedNeutered))
        XCTAssertEqual(result.estimatedIdealKg, 20.3)
        XCTAssertEqual(result.baselineCalories, 669)
        XCTAssertEqual(result.targetCalories, 535)
    }

    func testPoundsIdealWeightIsRoundedBeforeConversionToKilograms() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 30, unit: .lb, bcs: 7, reproductiveStatus: .spayedNeutered))
        XCTAssertEqual(result.currentKg, 13.6054421769, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(result.estimatedIdealKg), 11.3378684807, accuracy: 1e-9)
        XCTAssertEqual(result.baselineCalories, 433)
        XCTAssertEqual(result.targetCalories, 346)
        XCTAssertEqual(result.calorieFloor, 260)
    }

    func testNutritionWeightUnitConversionUsesPNASpecificConvention() {
        XCTAssertEqual(NutritionWeightUnit.lb.kilograms(22.05), 10, accuracy: 1e-12)
        XCTAssertEqual(NutritionWeightUnit.lb.value(fromKg: 10), 22.05, accuracy: 1e-12)
        XCTAssertEqual(NutritionWeightUnit.kg.kilograms(10), 10)
        XCTAssertEqual(NutritionWeightUnit.kg.value(fromKg: 10), 10)
    }

    func testUnsupportedScoresPreserveStatusButNeverInventAutomaticCalories() throws {
        for species in Species.allCases {
            for unit in NutritionWeightUnit.allCases {
                for status in NutritionReproductiveStatus.allCases {
                    let lastUnsupportedScore = species == .dog ? 4 : 3
                    for score in 1...lastUnsupportedScore {
                        let result = try XCTUnwrap(NutritionMath.estimate(species: species, weight: 10, unit: unit, bcs: score, reproductiveStatus: status, currentCalories: 900))
                        XCTAssertNil(result.estimatedIdealKg)
                        XCTAssertNil(result.planningRER)
                        XCTAssertNil(result.baselineCalories)
                        XCTAssertNil(result.targetCalories)
                        XCTAssertNil(result.calorieFloor)
                        XCTAssertEqual(result.weightStatus, score == 4 ? "Ideal range" : "Underweight")
                        XCTAssertEqual(result.goal, score == 4 ? .maintain : .gain)
                    }
                }
            }
        }
    }

    func testDogBCSFourIsIdealRangeButOutsidePNAAutomaticScope() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 10, unit: .kg, bcs: 4, reproductiveStatus: .intact))
        XCTAssertEqual(result.weightStatus, "Ideal range")
        XCTAssertNil(result.targetCalories)
        XCTAssertTrue(result.caution.contains("outside PNA"))
        XCTAssertFalse(result.caution.contains("refeeding"))
    }

    func testClinicianTargetForUnderweightPatientIsReferenceOnly() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 15, unit: .lb, bcs: 2, reproductiveStatus: .spayedNeutered, currentCalories: 500, clinicianTargetWeight: 22.05))
        XCTAssertEqual(try XCTUnwrap(result.clinicianTargetKg), 10, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(result.planningRER), 393.6389276, accuracy: 0.0001)
        XCTAssertNil(result.estimatedIdealKg)
        XCTAssertNil(result.targetCalories)
        XCTAssertTrue(result.caution.contains("not a feeding prescription"))
        XCTAssertTrue(result.caution.contains("refeeding"))
    }

    func testClinicianTargetNeverReplacesSupportedPNACalculation() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 30, unit: .kg, bcs: 7, reproductiveStatus: .intact, clinicianTargetWeight: 20))
        XCTAssertEqual(result.clinicianTargetKg, 20)
        XCTAssertEqual(result.estimatedIdealKg, 25)
        XCTAssertEqual(result.targetCalories, 626)
    }

    func testWeightStatusUsesSelectedBCSRatherThanCurrentWeight() throws {
        let statuses = ["Underweight", "Underweight", "Underweight", "Ideal range", "Ideal range", "Overweight", "Obese (PNA)", "Obese (PNA)", "Obese (PNA)"]
        for species in Species.allCases {
            for (index, expected) in statuses.enumerated() {
                for weight in [2.0, 50.0] {
                    let result = try XCTUnwrap(NutritionMath.estimate(species: species, weight: weight, unit: .kg, bcs: index + 1, reproductiveStatus: .spayedNeutered))
                    XCTAssertEqual(result.weightStatus, expected)
                }
            }
        }
    }

    func testEnteredCaloriesOverrideAutomaticBaselineAndIgnoreReproductiveMultiplier() throws {
        for species in Species.allCases {
            for status in NutritionReproductiveStatus.allCases {
                for (bcs, target) in [(5, 1001.0), (6, 900.0), (7, 800.0), (8, 800.0), (9, 800.0)] {
                    let result = try XCTUnwrap(NutritionMath.estimate(species: species, weight: 10, unit: .kg, bcs: bcs, reproductiveStatus: status, currentCalories: 1000.51))
                    XCTAssertEqual(result.baselineCalories, 1000.51)
                    XCTAssertEqual(result.targetCalories, target)
                }
            }
        }
    }

    func testCalorieFloorRejectsBelowThresholdButAcceptsRoundedBoundary() throws {
        let below = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 30, unit: .kg, bcs: 7, reproductiveStatus: .intact, currentCalories: 586.874))
        XCTAssertEqual(below.calorieFloor, 470)
        XCTAssertNil(below.targetCalories)
        XCTAssertEqual(below.estimatedIdealKg, 25)
        XCTAssertEqual(below.baselineCalories, 586.874)
        XCTAssertTrue(below.caution.contains("60%"))
        let boundary = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 30, unit: .kg, bcs: 7, reproductiveStatus: .intact, currentCalories: 586.875))
        XCTAssertEqual(boundary.targetCalories, 470)
        let maintenanceBelow = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 10, unit: .kg, bcs: 5, reproductiveStatus: .intact, currentCalories: 235.49))
        let maintenanceBoundary = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: 10, unit: .kg, bcs: 5, reproductiveStatus: .intact, currentCalories: 235.5))
        XCTAssertNil(maintenanceBelow.targetCalories)
        XCTAssertEqual(maintenanceBoundary.targetCalories, 236)
    }

    func testTinyWeightNeverProducesZeroCalorieFeedingPlan() throws {
        for score in [4, 5, 6, 9] {
            let result = try XCTUnwrap(NutritionMath.estimate(species: .cat, weight: 0.000001, unit: .kg, bcs: score, reproductiveStatus: .spayedNeutered))
            XCTAssertNil(result.targetCalories)
            XCTAssertTrue(result.currentRER.isFinite)
        }
    }

    func testInvalidInputsAreRejectedAcrossUnits() {
        for unit in NutritionWeightUnit.allCases {
            for invalid in [0, -1, Double.nan, Double.infinity, -Double.infinity, 1e24, unit == .kg ? 1001 : 2206] {
                XCTAssertNil(NutritionMath.estimate(species: .dog, weight: invalid, unit: unit, bcs: 5, reproductiveStatus: .intact))
                XCTAssertNil(NutritionMath.estimate(species: .dog, weight: 10, unit: unit, bcs: 5, reproductiveStatus: .intact, clinicianTargetWeight: invalid))
            }
        }
        for score in [-1, 0, 10, 100] {
            XCTAssertNil(NutritionMath.estimate(species: .dog, weight: 10, unit: .kg, bcs: score, reproductiveStatus: .intact))
        }
        for invalid in [0, -1, Double.nan, Double.infinity, -Double.infinity, 1_000_001] {
            XCTAssertNil(NutritionMath.estimate(species: .cat, weight: 4, unit: .kg, bcs: 5, reproductiveStatus: .intact, currentCalories: invalid))
        }
        XCTAssertTrue(NutritionMath.rer(kg: .nan).isNaN)
        XCTAssertTrue(NutritionMath.rer(kg: 0).isNaN)
        XCTAssertTrue(NutritionMath.rer(kg: 1001).isNaN)
    }

    func testOperationalUpperInputBoundsAreInclusive() throws {
        for unit in NutritionWeightUnit.allCases {
            let weight = unit == .kg ? 1000.0 : 2205.0
            let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, weight: weight, unit: unit, bcs: 5, reproductiveStatus: .spayedNeutered, currentCalories: 1_000_000, clinicianTargetWeight: weight))
            XCTAssertEqual(result.currentKg, 1000, accuracy: 1e-9)
            XCTAssertEqual(result.targetCalories, 1_000_000)
        }
    }
}
