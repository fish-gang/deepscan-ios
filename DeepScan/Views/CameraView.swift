import SwiftUI
import AVFoundation

struct CameraView: View {

    @State private var viewModel = CameraViewModel()

    @Binding var capturedImage: UIImage?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Spacer()

                    Button {
                        viewModel.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(!viewModel.isCameraReady)
                }
                .padding()

                Spacer()

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding()
                } else {
                    Button {
                        viewModel.capturePhoto()
                    } label: {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 56, height: 56)
                            )
                    }
                    .disabled(!viewModel.isCameraReady)
                    .opacity(viewModel.isCameraReady ? 1.0 : 0.5)
                }
            }
            .padding(.bottom, 32)
        }
        .task {
            await viewModel.checkPermissionsAndSetup()
        }
        .onChange(of: viewModel.capturedImage) { _, newImage in
            if let image = newImage {
                capturedImage = image
                viewModel.stopSession()
                dismiss()
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.capturedImage) { old, new in
            old == nil && new != nil
        }
        .sensoryFeedback(.selection, trigger: viewModel.currentPosition)
    }
}

// MARK: - Camera Preview Bridge

// AVCaptureVideoPreviewLayer has no native SwiftUI equivalent, so wrap it.
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

// makeUIView runs before layout (bounds == .zero at that point), so the
// preview layer frame must be reapplied in layoutSubviews once real bounds
// are known. Apple's AVCam sample follows the same pattern.
final class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
