import SwiftUI

struct FishPickerView: View {

    let image: UIImage
    let detections: [DetectedFish]
    let onRetake: () -> Void
    let onScanAnother: () -> Void

    @Environment(ClassifierViewModel.self) private var classifier

    @State private var selectedID: DetectedFish.ID?
    @State private var fishResult: FishResult?
    @State private var navigateToResults = false
    @State private var isClassifying = false

    var body: some View {
        VStack(spacing: 0) {
            photoCanvas
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .horizontal)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controlBar
        }
        .navigationTitle("Select a Fish")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Retake", systemImage: "arrow.counterclockwise", action: onRetake)
            }
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let result = fishResult {
                ResultsView(
                    result: result,
                    onScanAnother: onScanAnother,
                    // Pop one level back to the picker so the user can try
                    // a different fish from the same photo without restarting.
                    onPickAnotherFish: { navigateToResults = false }
                )
            }
        }
    }

    // MARK: - Photo + Bbox Overlays

    private var photoCanvas: some View {
        GeometryReader { proxy in
            // Compute the actual rendered image rect inside the proxy frame
            // so bbox overlays land on real image pixels, not on letterbox bars.
            let imageAspect = image.size.width / max(image.size.height, 1)
            let frameAspect = proxy.size.width / max(proxy.size.height, 1)
            let displayWidth: CGFloat = imageAspect > frameAspect
                ? proxy.size.width
                : proxy.size.height * imageAspect
            let displayHeight: CGFloat = imageAspect > frameAspect
                ? proxy.size.width / imageAspect
                : proxy.size.height
            let originX = (proxy.size.width - displayWidth) / 2
            let originY = (proxy.size.height - displayHeight) / 2

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                ForEach(Array(detections.enumerated()), id: \.element.id) { index, fish in
                    let rect = CGRect(
                        x: originX + fish.boundingBox.minX * displayWidth,
                        y: originY + fish.boundingBox.minY * displayHeight,
                        width: fish.boundingBox.width * displayWidth,
                        height: fish.boundingBox.height * displayHeight
                    )

                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            selectedID = fish.id
                        }
                    } label: {
                        BoxOverlay(
                            size: rect.size,
                            index: index + 1,
                            isSelected: fish.id == selectedID
                        )
                    }
                    .buttonStyle(.plain)
                    // .position centers the view at the given point AND moves
                    // the hit-testing region with it; .offset() would move the
                    // visual but leave taps registering at (0,0).
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityLabel("Fish \(index + 1) of \(detections.count)")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    // MARK: - Bottom Bar

    private var controlBar: some View {
        VStack(spacing: 10) {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: scanSelected) {
                HStack(spacing: 8) {
                    if isClassifying {
                        ProgressView()
                            .tint(.white)
                        Text("Scanning...")
                    } else {
                        Label("Scan This Fish", systemImage: "fish.fill")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(OceanTheme.aqua)
            .disabled(selectedID == nil || isClassifying)

            if let error = classifier.errorMessage {
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

    private var prompt: String {
        if selectedID == nil {
            return detections.count == 1
                ? "Tap the fish to select it."
                : "\(detections.count) fish detected — tap one to select."
        }
        return "Ready to scan."
    }

    // MARK: - Actions

    private func scanSelected() {
        guard let selectedID,
              let fish = detections.first(where: { $0.id == selectedID }),
              let cropped = ImageCrop.crop(image, to: fish.boundingBox) else {
            return
        }

        isClassifying = true
        Task {
            if let result = await classifier.classify(image: cropped) {
                fishResult = result
                navigateToResults = true
            }
            isClassifying = false
        }
    }
}

// MARK: - Box Overlay

private struct BoxOverlay: View {
    let size: CGSize
    let index: Int
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? OceanTheme.aqua.opacity(0.18) : Color.clear)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? OceanTheme.aqua : .white.opacity(0.85),
                    lineWidth: isSelected ? 3 : 2
                )

            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    isSelected ? OceanTheme.aqua : Color.black.opacity(0.55),
                    in: Capsule()
                )
                .padding(6)
        }
        .frame(width: size.width, height: size.height)
        // Make the entire bbox area tappable, including the transparent fill.
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(isSelected ? 0.25 : 0.15), radius: 4, y: 2)
    }
}

#Preview {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
    let fakeImage = renderer.image { ctx in
        UIColor.systemTeal.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
    }
    let mockDetections = [
        DetectedFish(boundingBox: CGRect(x: 0.10, y: 0.18, width: 0.30, height: 0.26), confidence: 0.92),
        DetectedFish(boundingBox: CGRect(x: 0.55, y: 0.40, width: 0.28, height: 0.22), confidence: 0.78),
    ]
    return NavigationStack {
        FishPickerView(
            image: fakeImage,
            detections: mockDetections,
            onRetake: {},
            onScanAnother: {}
        )
        .environment(ClassifierViewModel())
    }
}
