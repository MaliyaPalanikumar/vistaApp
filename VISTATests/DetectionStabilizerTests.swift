//
//  DetectionStabilizerTests.swift
//  VISTATests
//

import XCTest
@testable import VISTA

final class DetectionStabilizerTests: XCTestCase {
    // MARK: - Isolated behaviors

    func test_singleConfidentSample_belowRequiredAgreement_isUnchanged() {
        let stabilizer = DetectionStabilizer(windowSize: 5, minimumConfidence: 0.5, requiredAgreement: 3, maxConsecutiveMisses: 8)
        assertUnchanged(stabilizer.stabilize(detection("stop")))
    }

    func test_lowConfidenceDetection_isTreatedAsAMiss_notShown() {
        let stabilizer = DetectionStabilizer(windowSize: 5, minimumConfidence: 0.5, requiredAgreement: 3, maxConsecutiveMisses: 8)
        assertUnchanged(stabilizer.stabilize(detection("stop", confidence: 0.2)))
    }

    func test_repeatingSameClass_reachesAgreementAndShows() {
        let stabilizer = DetectionStabilizer(windowSize: 5, minimumConfidence: 0.5, requiredAgreement: 3, maxConsecutiveMisses: 8)
        assertUnchanged(stabilizer.stabilize(detection("stop")))
        assertUnchanged(stabilizer.stabilize(detection("stop")))
        assertShows("stop", stabilizer.stabilize(detection("stop")))
    }

    func test_afterClear_singleSampleIsNotEnoughToShowAgain() {
        let stabilizer = DetectionStabilizer(windowSize: 3, minimumConfidence: 0.5, requiredAgreement: 2, maxConsecutiveMisses: 1)
        _ = stabilizer.stabilize(detection("stop"))
        assertShows("stop", stabilizer.stabilize(detection("stop")))
        assertClears(stabilizer.stabilize(nil)) // single miss hits maxConsecutiveMisses(1)

        assertUnchanged(stabilizer.stabilize(detection("stop")))
    }

    // MARK: - Full sequence: shows, eviction changing the winner, then clearing

    func test_fullSequence_showsEvictsAndClears() {
        let stabilizer = DetectionStabilizer(windowSize: 3, minimumConfidence: 0.5, requiredAgreement: 2, maxConsecutiveMisses: 2)

        assertUnchanged(stabilizer.stabilize(detection("a")))   // window: [a]
        assertShows("a", stabilizer.stabilize(detection("a")))  // window: [a,a]
        assertShows("a", stabilizer.stabilize(detection("b")))  // window: [a,a,b] — "a" still the majority
        assertShows("b", stabilizer.stabilize(detection("b")))  // oldest "a" evicted -> [a,b,b] — "b" now wins
        assertShows("b", stabilizer.stabilize(detection("b")))  // last "a" evicted -> [b,b,b]

        assertUnchanged(stabilizer.stabilize(nil)) // miss 1 of 2
        assertClears(stabilizer.stabilize(nil))    // miss 2 of 2 -> had a detection, so clear

        assertUnchanged(stabilizer.stabilize(nil)) // miss 1 of 2, nothing was showing
        assertUnchanged(stabilizer.stabilize(nil)) // miss 2 of 2, still nothing was showing -> unchanged, not clear
    }

    // MARK: - Helpers

    private func detection(_ id: String, confidence: Double = 0.9) -> TrafficSignDetection {
        TrafficSignDetection(id: id, name: id.capitalized, confidence: confidence)
    }

    private func assertUnchanged(_ result: StabilizedResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .unchanged = result else {
            return XCTFail("Expected .unchanged, got \(result)", file: file, line: line)
        }
    }

    private func assertClears(_ result: StabilizedResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .clear = result else {
            return XCTFail("Expected .clear, got \(result)", file: file, line: line)
        }
    }

    private func assertShows(_ expectedId: String, _ result: StabilizedResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .show(let shown) = result else {
            return XCTFail("Expected .show(\(expectedId)), got \(result)", file: file, line: line)
        }
        XCTAssertEqual(shown.id, expectedId, file: file, line: line)
    }
}
