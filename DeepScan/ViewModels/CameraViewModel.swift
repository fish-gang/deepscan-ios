import AVFoundation
import SwiftUI
import Combine

// @MainActor means all UI-related updates in this class automatically
// run on the main thread. This is important because AVFoundation does
// its heavy work on background threads, but SwiftUI can only be
// updated from the main thread - just like JavaFX's Platform.runLater().
@MainActor
class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    // @Published is like @State but lives in the ViewModel instead of the View.
    // Any View that watches this ViewModel will automatically re-render
    // when these values change. This is the reactive bridge between
    // ViewModel and View in MVVM.

    // The live camera session - this is the pipeline to the hardware camera
    let session = AVCaptureSession()

    // The photo that was just captured - Optional because no photo exists yet
    @Published var capturedImage: UIImage? = nil

    // Whether the camera is ready to use
    @Published var isCameraReady = false

    // Error message to show the user if something goes wrong
    @Published var errorMessage: String? = nil

    // MARK: - Private Properties

    // The object that handles the actual photo capture output
    private let photoOutput = AVCapturePhotoOutput()

    // MARK: - Setup

    // async means this function can be suspended while waiting
    // (e.g. waiting for the user to respond to a permission dialog)
    // without blocking the thread. Like CompletableFuture in Java.
    func checkPermissionsAndSetup() async {

        // AVFoundation requires explicit user permission to use the camera.
        // AVMediaType.video = the camera (confusingly named, but video covers
        // both photo and video capture)
        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            // User already granted permission previously
            setupSession()

        case .notDetermined:
            // First time asking - show the system permission dialog.
            // 'await' pauses here until the user taps Allow or Deny.
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
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

    // Sets up the AVCaptureSession pipeline:
    // [Camera Device] → [Session] → [Photo Output]
    //
    // Runs entirely on a background thread — AVCaptureSession configuration
    // is blocking work that should not happen on the main thread.
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

    // MARK: - Capture Photo

    func capturePhoto() {
        // AVCapturePhotoSettings configures how the photo is taken
        let settings = AVCapturePhotoSettings()
        // 'self' as delegate means this class will receive the callback
        // when the photo is ready (see extension below)
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // Stops the camera session - important to call this when leaving the
    // camera screen to free up hardware resources
    func stopSession() {
        let session = self.session
        Task.detached {
            session.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

// We extend CameraViewModel to conform to AVCapturePhotoCaptureDelegate.
// This is the delegate pattern - AVFoundation calls back into our code
// when the photo is ready. Similar to implementing an interface in Java.
extension CameraViewModel: AVCapturePhotoCaptureDelegate {

    // Called by AVFoundation when a photo has been captured and processed.
    // 'nonisolated' is needed because AVFoundation calls this from its own
    // thread, not the main thread. We then manually jump to MainActor
    // to update the UI safely.
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {

        // Convert the raw photo data to a UIImage
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        // Jump to the main thread to update @Published properties
        // This is the Swift equivalent of Platform.runLater() in JavaFX
        Task { @MainActor in
            self.capturedImage = image
        }
    }
}
