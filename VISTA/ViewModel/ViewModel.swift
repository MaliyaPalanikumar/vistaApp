//
//  ViewModel.swift
//  VISTA
//
//  Created by Maliya Palanikumar on 25/08/26.
//

import CoreGraphics
import CoreImage
import CoreMedia
import CoreML
import UIKit

/// Converts live camera frames into the exact input MobileNetV2.mlpackage expects.
///
/// The model was exported from Keras via `coremltools.convert(..., inputs: [ct.TensorType(...)])`

struct ViewModel {
    static let modelInputSize = CGSize(width: 224, height: 224)

    private let ciContext = CIContext()

    /// Renders a sample buffer's frame as a `UIImage`, center-cropped to a square
    /// and scaled to the model's 224x224 input size.
    /// Preprocessing layer for the model.
    func convertCMSampleBufferToImage(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let squared = CIImage(cvPixelBuffer: pixelBuffer).squareCropped()
        let scale = Self.modelInputSize.width / squared.extent.width
        let scaled = squared.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let outputRect = CGRect(origin: .zero, size: Self.modelInputSize)
        
        guard let cgImage = ciContext.createCGImage(
            scaled,
            from: outputRect,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func multiArray(from image: UIImage) -> MLMultiArray? {
        guard let cgImage = image.cgImage else { return nil }

        let width = Int(Self.modelInputSize.width)
        let height = Int(Self.modelInputSize.height)

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let multiArray = try? MLMultiArray(
            shape: [1, NSNumber(value: height), NSNumber(value: width), 3],
            dataType: .float32
        ) else {
            return nil
        }

        let tensor = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: multiArray.count)
        for pixelIndex in 0..<(width * height) {
            let rgba = pixelIndex * 4
            let tensorOffset = pixelIndex * 3
            // mobilenet_v2.preprocess_input: scale [0, 255] to [-1, 1] per RGB channel.
            tensor[tensorOffset] = Float32(pixels[rgba]) / 127.5 - 1.0
            tensor[tensorOffset + 1] = Float32(pixels[rgba + 1]) / 127.5 - 1.0
            tensor[tensorOffset + 2] = Float32(pixels[rgba + 2]) / 127.5 - 1.0
        }

        return multiArray
    }
}

private extension CIImage {

    func squareCropped() -> CIImage {
        let side = min(extent.width, extent.height)
        let origin = CGPoint(
            x: extent.origin.x + (extent.width - side) / 2,
            y: extent.origin.y + (extent.height - side) / 2
        )
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        return cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
    }
}
