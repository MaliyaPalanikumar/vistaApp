//
//  TestHelpers.swift
//  VISTATests
//
//  Shared synthetic fixtures for tests that need a CMSampleBuffer or UIImage
//  without a real camera — none of these touch AVCaptureSession or hardware.
//

import CoreMedia
import CoreVideo
import UIKit
import XCTest

enum SampleBufferFactory {
    /// A solid-color 32BGRA pixel buffer of the given size, for feeding into
    /// `ViewModel.convertCMSampleBufferToImage`.
    static func makePixelBuffer(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            preconditionFailure("Failed to create test pixel buffer")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            preconditionFailure("Test pixel buffer has no base address")
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        for row in 0..<height {
            let rowStart = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for column in 0..<width {
                let offset = column * 4
                // Pixel format is BGRA.
                rowStart[offset] = blue
                rowStart[offset + 1] = green
                rowStart[offset + 2] = red
                rowStart[offset + 3] = 255
            }
        }

        return buffer
    }

    /// Wraps a pixel buffer in a `CMSampleBuffer`, matching what
    /// `AVCaptureVideoDataOutput` would hand to the capture delegate.
    static func makeSampleBuffer(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer {
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard let formatDescription else {
            preconditionFailure("Failed to create test format description")
        }

        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            preconditionFailure("Failed to create test sample buffer")
        }
        return sampleBuffer
    }
}

enum ImageFactory {
    /// A solid-color image, useful for asserting exact tensor normalization
    /// math since every pixel is identical.
    static func solidImage(size: CGSize, red: CGFloat, green: CGFloat, blue: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(red: red, green: green, blue: blue, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }
    }
}
