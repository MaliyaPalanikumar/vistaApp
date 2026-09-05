//
//  CameraManager.swift
//  VISTA
//
//  Created by Maliya Palanikumar on 22/08/26.
//

import AVFoundation
import Combine

enum CameraAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Owns the AVCaptureSession for the back camera, classifies each frame with
/// MobileNetV2, and publishes the result via `currentDetection` for the view.
final class CameraManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CameraAuthorizationStatus = .notDetermined
    @Published var isSessionRunning = false
    @Published var setupError: String?

    /// The most recent classification result, shown in the bottom banner.
    @Published var currentDetection: TrafficSignDetection?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.vista.camera.sessionQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let viewModel = ViewModel()
    private let classifier = TrafficSignClassifier()
    private let stabilizer = DetectionStabilizer()

    /// Only run the model on every Nth frame — CoreML inference on all 30fps
    /// of camera frames is wasteful and doesn't make classification any more
    /// stable, since the stabilizer already smooths across samples.
    private let frameSkipInterval = 3
    private var frameCounter = 0

    override init() {
        super.init()
        session.sessionPreset = .high
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            configureSessionIfNeeded()
        case .notDetermined:
            authorizationStatus = .notDetermined
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.configureSessionIfNeeded()
                    }
                }
            }
        case .denied:
            authorizationStatus = .denied
        case .restricted:
            authorizationStatus = .restricted
        @unknown default:
            authorizationStatus = .denied
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        guard session.inputs.isEmpty else {
            startSession()
            return
        }

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            publishError("No back camera is available on this device.")
            return
        }

        session.beginConfiguration()

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            guard session.canAddInput(input) else {
                publishError("Unable to add the back camera as a capture input.")
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            guard session.canAddOutput(videoOutput) else {
                publishError("Unable to add the video output.")
                session.commitConfiguration()
                return
            }
            session.addOutput(videoOutput)
            videoOutput.connection(with: .video)?.videoOrientation = .portrait

            try backCamera.lockForConfiguration()
            if backCamera.isFocusModeSupported(.continuousAutoFocus) {
                backCamera.focusMode = .continuousAutoFocus
            }
            if backCamera.isExposureModeSupported(.continuousAutoExposure) {
                backCamera.exposureMode = .continuousAutoExposure
            }
            backCamera.unlockForConfiguration()
        } catch {
            publishError("Failed to configure the back camera: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
        startSession()
    }

    private func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = true
        }
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.setupError = message
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % frameSkipInterval == 0 else { return }

        guard let image = viewModel.convertCMSampleBufferToImage(sampleBuffer),
              let modelInput = viewModel.multiArray(from: image) else {
            return
        }

        let detection = classifier.classify(modelInput)

        let classifierError = classifier.lastError
        DispatchQueue.main.async { [weak self] in
            self?.setupError = classifierError
        }

        switch stabilizer.stabilize(detection) {
        case .show(let stableDetection):
            DispatchQueue.main.async { [weak self] in
                self?.currentDetection = stableDetection
            }
        case .clear:
            DispatchQueue.main.async { [weak self] in
                self?.currentDetection = nil
            }
        case .unchanged:
            break
        }
    }
}
