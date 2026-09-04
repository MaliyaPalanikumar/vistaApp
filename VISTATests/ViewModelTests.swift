//
//  ViewModelTests.swift
//  VISTATests
//

import CoreML
import UIKit
import XCTest
@testable import VISTA

final class ViewModelTests: XCTestCase {
    // MARK: - convertCMSampleBufferToImage

    func test_convertCMSampleBufferToImage_producesModelInputSizedSquare() throws {
        // A non-square source (like a real camera frame) to prove it's
        // center-cropped to a square, not just resized/distorted.
        let pixelBuffer = SampleBufferFactory.makePixelBuffer(width: 640, height: 480, red: 200, green: 50, blue: 50)
        let sampleBuffer = SampleBufferFactory.makeSampleBuffer(pixelBuffer: pixelBuffer)

        let image = ViewModel().convertCMSampleBufferToImage(sampleBuffer)

        let unwrapped = try XCTUnwrap(image)
        XCTAssertEqual(unwrapped.size.width, ViewModel.modelInputSize.width, accuracy: 0.5)
        XCTAssertEqual(unwrapped.size.height, ViewModel.modelInputSize.height, accuracy: 0.5)
    }

    func test_convertCMSampleBufferToImage_squareSourceStaysModelInputSized() throws {
        let pixelBuffer = SampleBufferFactory.makePixelBuffer(width: 480, height: 480, red: 10, green: 10, blue: 200)
        let sampleBuffer = SampleBufferFactory.makeSampleBuffer(pixelBuffer: pixelBuffer)

        let image = ViewModel().convertCMSampleBufferToImage(sampleBuffer)
        let unwrapped = try XCTUnwrap(image)

        XCTAssertEqual(unwrapped.size.width, ViewModel.modelInputSize.width, accuracy: 0.5)
        XCTAssertEqual(unwrapped.size.height, ViewModel.modelInputSize.height, accuracy: 0.5)
    }

    // MARK: - multiArray(from:)

    func test_multiArray_hasShapeAndDataTypeTheModelExpects() throws {
        let image = ImageFactory.solidImage(size: ViewModel.modelInputSize, red: 1, green: 1, blue: 1)
        let multiArray = try XCTUnwrap(ViewModel().multiArray(from: image))

        XCTAssertEqual(multiArray.shape, [1, 224, 224, 3] as [NSNumber])
        XCTAssertEqual(multiArray.dataType, .float32)
    }

    func test_multiArray_normalizesWhiteToPositiveOne() throws {
        let image = ImageFactory.solidImage(size: ViewModel.modelInputSize, red: 1, green: 1, blue: 1)
        let multiArray = try XCTUnwrap(ViewModel().multiArray(from: image))

        for channel in 0..<3 {
            XCTAssertEqual(Float(truncating: multiArray[channel]), 1.0, accuracy: 0.02)
        }
    }

    func test_multiArray_normalizesBlackToNegativeOne() throws {
        let image = ImageFactory.solidImage(size: ViewModel.modelInputSize, red: 0, green: 0, blue: 0)
        let multiArray = try XCTUnwrap(ViewModel().multiArray(from: image))

        for channel in 0..<3 {
            XCTAssertEqual(Float(truncating: multiArray[channel]), -1.0, accuracy: 0.02)
        }
    }

    func test_multiArray_normalizesMidGrayToApproximatelyZero() throws {
        let image = ImageFactory.solidImage(size: ViewModel.modelInputSize, red: 0.5, green: 0.5, blue: 0.5)
        let multiArray = try XCTUnwrap(ViewModel().multiArray(from: image))

        for channel in 0..<3 {
            XCTAssertEqual(Float(truncating: multiArray[channel]), 0.0, accuracy: 0.05)
        }
    }

    func test_multiArray_returnsNilWhenImageHasNoCGImage() {
        // The parameterless UIImage() has no backing CGImage or CIImage.
        XCTAssertNil(ViewModel().multiArray(from: UIImage()))
    }
}
