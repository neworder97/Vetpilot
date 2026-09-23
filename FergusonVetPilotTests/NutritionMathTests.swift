import XCTest
@testable import FergusonVetPilot

final class NutritionMathTests: XCTestCase {
    func testRERUsesMetabolicWeightEquation() {
        XCTAssertEqual(NutritionMath.rer(kg: 10), 393.6389276, accuracy: 0.0001)
    }

    func testDogWeightLossUsesIdealWeightAndOnePointZeroRER() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, currentKg: 30, bcs: 7))
        XCTAssertEqual(result.goal, .lose)
        XCTAssertEqual(result.estimatedIdealKg ?? .nan, 25, accuracy: 0.0001)
        XCTAssertEqual(result.targetCalories, NutritionMath.rer(kg: 25), accuracy: 0.0001)
    }

    func testCatWeightLossUsesZeroPointEightRER() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .cat, currentKg: 6, bcs: 7))
        XCTAssertEqual(result.goal, .lose)
        XCTAssertEqual(result.estimatedIdealKg ?? .nan, 5, accuracy: 0.0001)
        XCTAssertEqual(result.targetCalories, NutritionMath.rer(kg: 5) * 0.8, accuracy: 0.0001)
    }

    func testBCSFourAndFiveAreTreatedAsIdealRange() throws {
        let dog = try XCTUnwrap(NutritionMath.estimate(species: .dog, currentKg: 10, bcs: 4))
        let cat = try XCTUnwrap(NutritionMath.estimate(species: .cat, currentKg: 4, bcs: 5))
        XCTAssertEqual(dog.goal, .maintain)
        XCTAssertEqual(dog.estimatedIdealKg ?? .nan, 10, accuracy: 0.0001)
        XCTAssertEqual(cat.goal, .maintain)
        XCTAssertEqual(cat.estimatedIdealKg ?? .nan, 4, accuracy: 0.0001)
    }

    func testDogIdealBCSMaintenanceRange() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, currentKg: 10, bcs: 5))
        XCTAssertEqual(result.goal, .maintain)
        XCTAssertEqual(result.lowCalories, NutritionMath.rer(kg: 10) * 1.4, accuracy: 0.0001)
        XCTAssertEqual(result.highCalories, NutritionMath.rer(kg: 10) * 1.6, accuracy: 0.0001)
    }

    func testCatIdealBCSMaintenanceRange() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .cat, currentKg: 4, bcs: 5))
        XCTAssertEqual(result.goal, .maintain)
        XCTAssertEqual(result.lowCalories, NutritionMath.rer(kg: 4) * 1.2, accuracy: 0.0001)
        XCTAssertEqual(result.highCalories, NutritionMath.rer(kg: 4) * 1.4, accuracy: 0.0001)
    }

    func testUnderweightDogUsesCurrentWeightMonitoredGainRange() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .dog, currentKg: 10, bcs: 3))
        XCTAssertEqual(result.goal, .gain)
        XCTAssertNil(result.estimatedIdealKg)
        XCTAssertEqual(result.lowCalories, NutritionMath.rer(kg: 10) * 1.6, accuracy: 0.0001)
        XCTAssertEqual(result.targetCalories, NutritionMath.rer(kg: 10) * 1.7, accuracy: 0.0001)
        XCTAssertEqual(result.highCalories, NutritionMath.rer(kg: 10) * 1.8, accuracy: 0.0001)
    }

    func testUnderweightCatUsesCurrentWeightMonitoredGainRange() throws {
        let result = try XCTUnwrap(NutritionMath.estimate(species: .cat, currentKg: 3.2, bcs: 3))
        XCTAssertEqual(result.goal, .gain)
        XCTAssertNil(result.estimatedIdealKg)
        XCTAssertEqual(result.lowCalories, NutritionMath.rer(kg: 3.2) * 1.4, accuracy: 0.0001)
        XCTAssertEqual(result.targetCalories, NutritionMath.rer(kg: 3.2) * 1.5, accuracy: 0.0001)
        XCTAssertEqual(result.highCalories, NutritionMath.rer(kg: 3.2) * 1.6, accuracy: 0.0001)
    }

    func testAllValidBCSScoresProduceFinitePositiveCaloriesForDogsAndCats() throws {
        for species in [Species.dog, Species.cat] {
            for score in 1...9 {
                let result = try XCTUnwrap(NutritionMath.estimate(species: species, currentKg: 8, bcs: score))
                XCTAssertTrue(result.targetCalories.isFinite)
                XCTAssertGreaterThan(result.targetCalories, 0)
                if let idealKg = result.estimatedIdealKg { XCTAssertGreaterThan(idealKg, 0) }
            }
        }
    }

    func testRejectsOversizedAndNonfiniteWeight() {
        for kg in [1e24, Double.infinity, Double.nan, 1001, -1, 0] {
            XCTAssertNil(NutritionMath.estimate(species: .dog, currentKg: kg, bcs: 5))
        }
    }

    func testRejectsInvalidWeightAndBCS() {
        XCTAssertNil(NutritionMath.estimate(species: .dog, currentKg: 0, bcs: 5))
        XCTAssertNil(NutritionMath.estimate(species: .cat, currentKg: 4, bcs: 10))
        XCTAssertTrue(NutritionMath.rer(kg: .nan).isNaN)
    }
}
