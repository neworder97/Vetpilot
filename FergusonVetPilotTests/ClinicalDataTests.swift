import XCTest
import UIKit
@testable import FergusonVetPilot

final class ClinicalDataTests: XCTestCase {
    func testWeightConversionRoundTrip() {
        XCTAssertEqual(ClinicalData.lbToKg(ClinicalData.kgToLb(10)), 10, accuracy: 0.00001)
    }

    func testCarprofenMath() throws {
        let med = try XCTUnwrap(
            ClinicalData.searchMedications(query: "carprofen", species: .dog, form: .tablet).first
        )
        let result = ClinicalData.calculate(medication: med, kg: 10, strength: 25, concentration: nil)
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.contains("44 mg"))
        XCTAssertTrue(result.formulation.contains("1.76"))
    }

    func testMiratazDoesNotConvertToMilliliters() throws {
        let med = try XCTUnwrap(
            ClinicalData.searchMedications(query: "mirataz", species: .cat, form: .transdermal).first
        )
        let result = ClinicalData.calculate(medication: med, kg: 4, strength: nil, concentration: nil)
        XCTAssertTrue(result.headline.contains("2 mg"))
        XCTAssertTrue(result.formulation.contains("1.5-inch ribbon"))
        XCTAssertFalse(result.formulation.contains("mL"))
    }

    func testControlledProtocolIsBlocked() throws {
        let med = try XCTUnwrap(
            ClinicalData.searchMedications(query: "phenobarbital", species: .dog, form: .tablet).first
        )
        XCTAssertFalse(ClinicalData.calculate(medication: med, kg: 20, strength: nil, concentration: nil).available)
    }


    func testMedicationLibraryHasAtLeast100Entries() {
        XCTAssertGreaterThanOrEqual(ClinicalData.medications.count, 100)
    }

    func testGabapentinDogChronicPainReferenceMath() throws {
        let med = try XCTUnwrap(
            ClinicalData.searchMedications(query: "gabapentin", species: .dog, form: .capsule).first
        )
        let result = ClinicalData.calculate(medication: med, kg: 10, strength: 100, concentration: nil)
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.contains("100–150 mg"))
        XCTAssertTrue(med.source.contains("MSD Veterinary Manual"))
    }

    func testTrazodoneDogSituationalReferenceMath() throws {
        let med = try XCTUnwrap(
            ClinicalData.searchMedications(query: "trazodone", species: .dog, form: .tablet).first
        )
        let result = ClinicalData.calculate(medication: med, kg: 10, strength: 50, concentration: nil)
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.contains("50–75 mg"))
        XCTAssertTrue(med.source.contains("MSD Veterinary Manual"))
    }

    func testCustomMedicationEquationAndSourceBadge() {
        let custom = CustomMedicationDefinition(
            generic: "TestMed",
            brand: "",
            drugClass: "Test",
            speciesRaw: Species.dog.rawValue,
            formRaw: MedicationForm.tablet.rawValue,
            indication: "Test indication",
            doseBasisRaw: CustomDoseBasis.mgKg.rawValue,
            minDose: 10,
            maxDose: 10,
            frequency: "q12h",
            route: "PO",
            concentration: nil,
            sourceReference: "Clinic formulary page 1",
            notes: ""
        )
        let med = custom.asMedication
        let result = ClinicalData.calculate(medication: med, kg: 5, strength: nil, concentration: nil)
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.contains("50 mg"))
        XCTAssertTrue(med.source.hasPrefix("USER-SOURCE-BACKED"))
    }


    func testRadiographPixelMetricsPreferGrayscaleContrast() {
        let size = CGSize(width: 64, height: 64)
        let xrayLike = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 16, y: 8, width: 32, height: 48))
        }

        let colorPhotoLike = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor.blue.setFill()
            context.cgContext.fill(CGRect(x: 16, y: 8, width: 32, height: 48))
        }

        let xrayMetrics = RadiographImageInspector.pixelMetrics(xrayLike)
        let colorMetrics = RadiographImageInspector.pixelMetrics(colorPhotoLike)

        XCTAssertGreaterThan(xrayMetrics.grayRatio, 0.95)
        XCTAssertLessThan(colorMetrics.grayRatio, 0.2)
        XCTAssertGreaterThan(xrayMetrics.contrast, 0.1)
    }

    func testRadiologyReferenceSearchURLs() {
        let google = RadiologyAIService.googleImagesURL(
            species: .dog,
            region: "thorax",
            searchTerms: ["cardiomegaly", "pulmonary edema"]
        )
        let vin = RadiologyAIService.vinSearchURL(
            species: .dog,
            region: "thorax",
            searchTerms: ["cardiomegaly"]
        )

        XCTAssertNotNil(google)
        XCTAssertNotNil(vin)
        XCTAssertTrue(google?.absoluteString.contains("tbm=isch") == true)

        let vinQuery = vin.flatMap { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "q" })?
                .value
        }
        XCTAssertTrue(vinQuery?.contains("site:vin.com") == true)
    }

    func testGermanShepherdSearch() {
        XCTAssertFalse(ClinicalData.searchBreeds(species: .dog, query: "German Shepherd").isEmpty)
    }

    func testRadiologyFeatureExtractorMeasuresRealImageAsymmetry() throws {
        let size = CGSize(width: 128, height: 128)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.85, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 64, y: 0, width: 64, height: 128))
        }

        let features = try XCTUnwrap(RadiologyAIService.extractFeatures(from: image))
        XCTAssertGreaterThan(features.leftRightDifference, 0.5)
        XCTAssertGreaterThan(features.contrast, 0.2)
        XCTAssertGreaterThan(features.dynamicRange, 0.7)
    }

    func testRadiologyFeatureExtractorReportsLowContrast() throws {
        let size = CGSize(width: 128, height: 128)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }

        let features = try XCTUnwrap(RadiologyAIService.extractFeatures(from: image))
        XCTAssertLessThan(features.contrast, 0.01)
        XCTAssertTrue(features.qualitySummary.lowercased().contains("contrast"))
    }

    func testRadiologyFeatureExtractorIgnoresUniformCollimationBorder() throws {
        let size = CGSize(width: 256, height: 256)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            UIColor(white: 0.32, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 40, y: 40, width: 176, height: 176))
            UIColor(white: 0.78, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 88, y: 72, width: 80, height: 112))
        }

        let features = try XCTUnwrap(RadiologyAIService.extractFeatures(from: image))
        XCTAssertLessThan(features.darkFraction, 0.20, "Uniform black collimation should not dominate image measurements")
        XCTAssertGreaterThan(features.dynamicRange, 0.35)
        XCTAssertGreaterThan(features.meanLuminance, 0.30)
    }

    func testRadiologyFeatureExtractorHonorsUIImageOrientation() throws {
        let size = CGSize(width: 160, height: 80)
        let base = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.15, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.85, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 80, y: 0, width: 80, height: 80))
        }
        let cgImage = try XCTUnwrap(base.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: .left)

        let normalFeatures = try XCTUnwrap(RadiologyAIService.extractFeatures(from: base))
        let rotatedFeatures = try XCTUnwrap(RadiologyAIService.extractFeatures(from: rotated))

        XCTAssertGreaterThan(normalFeatures.leftRightDifference, normalFeatures.topBottomDifference)
        XCTAssertGreaterThan(rotatedFeatures.topBottomDifference, rotatedFeatures.leftRightDifference)
        XCTAssertEqual(normalFeatures.contrast, rotatedFeatures.contrast, accuracy: 0.08)
    }

    func testProductionRadiologyPipelineWithRealCanineThoraxFixture() async throws {
        guard let url = Bundle(for: ClinicalDataTests.self).url(
            forResource: "dog_thorax_vd_test",
            withExtension: "jpg",
            subdirectory: "Fixtures"
        ) ?? Bundle(for: ClinicalDataTests.self).url(forResource: "dog_thorax_vd_test", withExtension: "jpg"),
        let image = UIImage(contentsOfFile: url.path) else {
            XCTFail("Required real radiograph fixture is missing. Run ValidationPrepared/run_ios_validation.sh; this is a failed validation, not a skipped success.")
            return
        }

        let inspection = await RadiographImageInspector.inspect(image)
        XCTAssertEqual(inspection.verdict, .likelyRadiograph)
        XCTAssertGreaterThanOrEqual(inspection.score, 0.67)
        XCTAssertTrue(inspection.canAnalyze)

        let result = try await RadiologyAIService.shared.analyze(
            image: image,
            species: .dog,
            studyRegion: "thorax VD",
            clinicalHistory: "CI production-pipeline validation",
            priorConfirmedCases: "",
            inspection: inspection
        )

        XCTAssertTrue(result.isRadiograph)
        XCTAssertFalse(result.findings.isEmpty)
        XCTAssertFalse(result.differentials.isEmpty)
        XCTAssertFalse(result.crossReferenceSummary.isEmpty)
        XCTAssertFalse(result.references.isEmpty)
        XCTAssertTrue(result.references.contains { $0.url.contains("acvr.org") })
        XCTAssertTrue(result.references.contains { $0.url.contains("vet.cornell.edu") })
        XCTAssertTrue(result.studyAssessment.lowercased().contains("thorax vd"))

        let encoded = try JSONEncoder().encode(result)
        let resultText = String(data: encoded, encoding: .utf8) ?? "Unable to encode result"
        print("VETPILOT_PRODUCTION_XRAY_RESULT=\(resultText)")
        let attachment = XCTAttachment(string: resultText)
        attachment.name = "Production X-ray scan result (real canine VD thorax fixture)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
