import AVFoundation
import SwiftUI

@MainActor
@Observable
final class CameraViewModel: NSObject {

    // MARK: - Observable State

    let session = AVCaptureSession()

    var capturedImage: UIImage?
    var isCameraReady = false
    var errorMessage: String?

    // MARK: - Private

    @ObservationIgnored private let photoOutput = AVCapturePhotoOutput()

    // MARK: - Setup

    func checkPermissionsAndSetup() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()

        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                setupSession()
            } else {
                errorMessage = "Camera access denied. Please enable it in Settings."
            }

        case .denied, .restricted:
            errorMessage = "Camera access denied. Please enable it in Settings."

        @unknown default:
            errorMessage = "Unknown camera permission status."
        }
    }

    // AVCaptureSession configuration is blocking — keep it off the main thread.
    private func setupSession() {
        let session = self.session
        let photoOutput = self.photoOutput
        // Hoist the weak reference before entering the detached task so we
        // capture a plain local (not a @MainActor var), which Swift 6 permits.
        weak let weakSelf = self

        Task.detached(priority: .userInitiated) {
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ) else {
                session.commitConfiguration()
                await MainActor.run { weakSelf?.errorMessage = "No camera found on this device." }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) { session.addInput(input) }
                if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
                session.commitConfiguration()
                await MainActor.run { weakSelf?.isCameraReady = true }
                session.startRunning()
            } catch {
                session.commitConfiguration()
                await MainActor.run {
                    weakSelf?.errorMessage = "Failed to set up camera: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func stopSession() {
        let session = self.session
        Task.detached {
            session.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {

    // AVFoundation invokes this on its own queue; hop back to the main actor
    // before touching observable state.
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        Task { @MainActor in
            self.capturedImage = image
        }
    }
}
