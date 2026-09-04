//
//  CameraManagerTests.swift
//  VISTATests
//
//  CameraManager is mostly a thin AVCaptureSession wrapper, and exercising
//  real capture (permission prompts, a live session, actual camera frames)
//  needs hardware a simulator/CI unit test doesn't have. This only checks
//  the state `init()` establishes before any capture session work starts —
//  deeper coverage of `checkAuthorization()`/`captureOutput(...)` would need
//  device hardware or injectable AVFoundation seams that don't exist yet.
//

import XCTest
@testable import VISTA

final class CameraManagerTests: XCTestCase {
    func test_init_startsWithNoAuthorizationDecisionOrDetection() {
        let manager = CameraManager()

        // CameraAuthorizationStatus isn't Equatable, so switch rather than XCTAssertEqual.
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        default:
            XCTFail("Expected .notDetermined immediately after init, got \(manager.authorizationStatus)")
        }
        XCTAssertFalse(manager.isSessionRunning)
        XCTAssertNil(manager.setupError)
        XCTAssertNil(manager.currentDetection)
    }
}
