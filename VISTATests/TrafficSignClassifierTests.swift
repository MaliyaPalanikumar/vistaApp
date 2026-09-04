//
//  TrafficSignClassifierTests.swift
//  VISTATests
//
//  This target runs hosted inside VISTA.app (see TEST_HOST/BUNDLE_LOADER in
//  the project settings), so the bundled MobileNetV2.mlmodelc really is
//  reachable here — these run the real model, not a mock.
//

import CoreML
import XCTest
@testable import VISTA

final class TrafficSignClassifierTests: XCTestCase {
    func test_init_loadsTheBundledModel() {
        let classifier = TrafficSignClassifier()
        XCTAssertNil(classifier.lastError, "Model failed to load: \(classifier.lastError ?? "")")
    }

    func test_classify_withCorrectlyShapedInput_returnsAPlausibleDetection() throws {
        let classifier = TrafficSignClassifier()
        let input = try MLMultiArray(shape: [1, 224, 224, 3], dataType: .float32)
        // Leave the tensor zero-filled — the model doesn't need a real sign
        // photo to exercise the plumbing from raw output to TrafficSignDetection.

        let detection = try XCTUnwrap(classifier.classify(input))

        XCTAssertFalse(detection.id.isEmpty)
        XCTAssertFalse(detection.name.isEmpty)
        XCTAssertGreaterThanOrEqual(detection.confidence, 0)
        XCTAssertLessThanOrEqual(detection.confidence, 1)
        XCTAssertNil(classifier.lastError)
    }

    func test_classify_withWrongShapedInput_returnsNilAndSetsError() throws {
        let classifier = TrafficSignClassifier()
        let malformedInput = try MLMultiArray(shape: [1, 10, 10, 3], dataType: .float32)

        let detection = classifier.classify(malformedInput)

        XCTAssertNil(detection)
        XCTAssertNotNil(classifier.lastError)
    }
}
