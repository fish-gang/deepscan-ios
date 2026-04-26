import SwiftUI
import AVFoundation

struct CameraView: View {

    // @StateObject creates and owns the ViewModel instance.
    // Use @StateObject when the View is responsible for creating the ViewModel.
    // Think of it as: this View is the "owner" of this ViewModel.
    @StateObject private var viewModel = CameraViewModel()

    // This is passed in from HomeView - when a photo is captured,
    // we write it back to HomeView via this binding.
    // Remember: @Binding = two-way connection to a parent's @State
    @Binding var capturedImage: UIImage?

    // Lets us dismiss this view (close the camera screen)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {

            // MARK: - Camera Preview
            // CameraPreviewView is a UIKit bridge (see below)
            // It shows the live camera feed as a background
            CameraPreviewView(session: viewModel.session)
                .ignoresSafeArea()

            // MARK: - Overlay
            VStack {
                // Top bar with cancel button
                HStack {
                    Button(action: {
                        viewModel.stopSession()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            // .background with material gives a frosted glass effect
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                // Bottom area - capture button or error message
                if let error = viewModel.errorMessage {
                    // Show error if camera setup failed
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding()
                } else {
                    // Capture button
                    Button(action: {
                        viewModel.capturePhoto()
                    }) {
                        // Outer ring
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                            .overlay(
                                // Inner filled circle
                                Circle()
                                    .fill(.white)
                                    .frame(width: 56, height: 56)
                            )
                    }
                    // Disable the button until camera is ready
                    .disabled(!viewModel.isCameraReady)
                    .opacity(viewModel.isCameraReady ? 1.0 : 0.5)
                }
            }
            .padding(.bottom, 32)
        }

        // .task runs an async function when the view appears.
        // It's the SwiftUI equivalent of viewDidAppear in UIKit.
        // We use it to kick off camera setup when the screen opens.
        .task {
            await viewModel.checkPermissionsAndSetup()
        }

        // Watch for a captured photo - when it arrives, pass it
        // back to HomeView via the binding and dismiss this screen
        .onChange(of: viewModel.capturedImage) { _, newImage in
            if let image = newImage {
                capturedImage = image
                viewModel.stopSession()
                dismiss()
            }
        }
    }
}

// MARK: - Camera Preview Bridge

// AVCaptureVideoPreviewLayer has no native SwiftUI equivalent,
// so we wrap it using UIViewRepresentable.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}

// Custom UIView so layoutSubviews keeps the preview layer sized correctly.
// makeUIView runs before layout (bounds == .zero at that point), so we
// can't rely on setting the frame there. layoutSubviews fires once real
// bounds are known — this is the Apple-recommended pattern (see AVCam sample).
class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
