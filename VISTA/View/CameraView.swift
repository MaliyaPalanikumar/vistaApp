//
//  CameraView.swift
//  VISTA
//
//  Created by Maliya Palanikumar on 22/08/26.
//

import SwiftUI
import AVFoundation

/// Full-screen live feed from the device's back camera, handling permission
/// states and surfacing capture errors. This is the entry point that will
/// later stream frames into the on-device MobileNetV2 model.
struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraManager.authorizationStatus {
            case .authorized:
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Spacer()

                    if let error = cameraManager.setupError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 24)
                    }

                    if let detection = cameraManager.currentDetection {
                        DetectionBannerView(detection: detection)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: cameraManager.currentDetection)

            case .notDetermined:
                ProgressView("Requesting camera access…")
                    .tint(.white)
                    .foregroundStyle(.white)

            case .denied, .restricted:
                CameraPermissionDeniedView()
            }
        }
        .onAppear { cameraManager.checkAuthorization() }
        .onDisappear { cameraManager.stopSession() }
    }
}

/// Wraps AVCaptureVideoPreviewLayer so SwiftUI can render the live camera feed.
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateOrientation()
        }

        private func updateOrientation() {
            guard let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported else { return }
            let orientation: AVCaptureVideoOrientation
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                orientation = .landscapeRight
            case .landscapeRight:
                orientation = .landscapeLeft
            case .portraitUpsideDown:
                orientation = .portraitUpsideDown
            default:
                orientation = .portrait
            }
            connection.videoOrientation = orientation
        }
    }
}

/// Bottom-of-screen banner showing the most recently detected traffic sign's
/// name and reference image.
private struct DetectionBannerView: View {
    let detection: TrafficSignDetection

    var body: some View {
        HStack(spacing: 12) {
            signImage
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(6)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(detection.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(Int(detection.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    private var signImage: Image {
        if UIImage(named: detection.imageName) != nil {
            return Image(detection.imageName).resizable()
        }
        return Image(systemName: "exclamationmark.triangle.fill")
    }
}

private struct CameraPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
            Text("Camera Access Needed")
                .font(.headline)
                .foregroundStyle(.white)
            Text("VISTA uses the back camera to detect traffic signs in real time. Enable camera access in Settings to continue.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    CameraView()
}

#Preview("Detection Banner") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            DetectionBannerView(
                detection: TrafficSignDetection(id: "stop", name: "Stop", confidence: 0.94)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}
