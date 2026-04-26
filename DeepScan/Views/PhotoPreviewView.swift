import SwiftUI

struct PhotoPreviewView: View {

    let image: UIImage
    let onRetake: () -> Void
    let onScanAnother: () -> Void

    // Injected from DeepScanApp — model is loaded once at launch, not here.
    @EnvironmentObject private var classifier: ClassifierViewModel

    // Holds the result once classification is done
    // Optional because no result exists until the model runs
    @State private var fishResult: FishResult? = nil
    @State private var navigateToResults = false

    // Controls the loading state while model is running
    @State private var isClassifying = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text("Does this look good?")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                HStack(spacing: 16) {

                    Button(action: onRetake) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isClassifying)

                    Button(action: {
                        isClassifying = true
                        Task {
                            if let result = await classifier.classify(image: image) {
                                fishResult = result
                                navigateToResults = true
                            }
                            isClassifying = false
                        }
                    }) {
                        HStack {
                            if isClassifying {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                            }
                            Label(
                                isClassifying ? "Scanning..." : "Scan Fish",
                                systemImage: isClassifying ? "" : "fish.fill"
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isClassifying)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                if let error = classifier.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let result = fishResult {
                ResultsView(result: result, onScanAnother: onScanAnother)
            }
        }
    }
}

#Preview {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 844))
    let fakeImage = renderer.image { ctx in
        UIColor.systemTeal.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 390, height: 844))
    }
    return PhotoPreviewView(image: fakeImage, onRetake: {}, onScanAnother: {})
        .environmentObject(ClassifierViewModel())
}
