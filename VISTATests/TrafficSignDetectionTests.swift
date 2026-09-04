//
//  TrafficSignDetectionTests.swift
//  VISTATests
//

import XCTest
@testable import VISTA

final class TrafficSignDetectionTests: XCTestCase {
    func test_imageName_matchesId() {
        let detection = TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.9)
        XCTAssertEqual(detection.imageName, "stop")
    }

    func test_init_assignsAllFields() {
        let detection = TrafficSignDetection(id: "priority_road", name: "Priority Road", confidence: 0.42)
        XCTAssertEqual(detection.id, "priority_road")
        XCTAssertEqual(detection.name, "Priority Road")
        XCTAssertEqual(detection.confidence, 0.42, accuracy: 0.0001)
    }

    func test_equatable_sameValuesAreEqual() {
        let a = TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.9)
        let b = TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.9)
        XCTAssertEqual(a, b)
    }

    func test_equatable_differingConfidenceAreNotEqual() {
        let a = TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.9)
        let b = TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.5)
        XCTAssertNotEqual(a, b)
    }

    func test_equatable_differingIdAreNotEqual() {
        let a = TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.9)
        let b = TrafficSignDetection(id: "yield_right_of_way", name: "Stop", confidence: 0.9)
        XCTAssertNotEqual(a, b)
    }
}
