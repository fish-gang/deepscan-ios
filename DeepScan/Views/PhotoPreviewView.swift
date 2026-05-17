import SwiftUI

struct PhotoPreviewView: View {

    let image: UIImage
    let onRetake: () -> Void
    let onScanAnother: () -> Void

    @Environment(ClassifierViewModel.self) private var classifier
    @Environment(DetectorViewModel.self) private var detector

    @State private var phase: ScanPhase = .idle
    @State private var detections: [DetectedFish] = []
    @State private var fishResult: FishResult?
    @State private var navigateToPicker = false
    @State private var navigateToResults = false

    enum ScanPhase: Equatable {
        case idle
        case detecting
        case classifying
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            controlsPanel
        }
        .navigationDestination(isPresented: $navigateToPicker) {
            FishPickerView(
                image: image,
                detections: detections,
                onRetake: onRetake,
                onScanAnother: onScanAnother
            )
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let result = fishResult {
                ResultsView(result: result, onScanAnother: onScanAnother)
            }
        }
    }

    // MARK: - Bottom Controls

    private var controlsPanel: some View {
        VStack(spacing: 12) {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: onRetake) {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.white)
                .disabled(isBusy)

                Button(action: scan) {
                    HStack(spacing: 8) {
                        if isBusy {
                            Image(systemName: "fish.fill")
                                .symbolEffect(.pulse, options: .repeating, isActive: isBusy)
                                .foregroundStyle(.white)
                            Text(busyLabel)
                        } else {
                            Label("Scan Fish", systemImage: "fish.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(OceanTheme.aqua)
                .disabled(isBusy)
            }

            if let error = classifier.errorMessage ?? detector.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private var isBusy: Bool {
        phase == .detecting || phase == .classifying
    }

    private var busyLabel: String {
        switch phase {
        case .detecting: return "Detecting..."
        case .classifying: return "Scanning..."
        default: return ""
        }
    }

    private var prompt: String {
        switch phase {
        case .idle:
            return "Does this look good?"
        case .detecting:
            return "Looking for fish..."
        case .classifying:
            return "Identifying species..."
        }
    }

    // MARK: - Scan

    private func scan() {
        phase = .detecting
        Task {
            let found = await detector.detect(image: image)

            switch found.count {
            case 0:
                // Detector found nothing. Either the photo isn't a fish, or
                // the detector missed (common for fish that fill the frame).
                // Either way, hand the whole image to the classifier — its
                // `no_fish` sentinel will catch genuinely non-fish photos.
                await classify(image)

            case 1:
                // Single fish — skip the picker, classify the cropped region.
                let cropped = ImageCrop.crop(image, to: found[0].boundingBox) ?? image
                await classify(cropped)

            default:
                // Multiple fish — let the user pick which one to scan.
                detections = found
                phase = .idle
                navigateToPicker = true
            }
        }
    }

    private func classify(_ imageToClassify: UIImage) async {
        phase = .classifying
        if let result = await classifier.classify(image: imageToClassify) {
            fishResult = result
            navigateToResults = true
        }
        phase = .idle
    }
}

#Preview {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 844))
    let fakeImage = renderer.image { ctx in
        UIColor.systemTeal.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 390, height: 844))
    }
    return NavigationStack {
        PhotoPreviewView(image: fakeImage, onRetake: {}, onScanAnother: {})
            .environment(ClassifierViewModel())
            .environment(DetectorViewModel())
    }
}
