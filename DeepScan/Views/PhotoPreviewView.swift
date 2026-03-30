import SwiftUI

struct PhotoPreviewView: View {

    let image: UIImage
    let onRetake: () -> Void

    // Track whether to navigate to results
    @State private var navigateToResults = false

    var body: some View {
        // NavigationStack here because PhotoPreviewView is presented
        // as a sheet - it needs its own navigation container
        NavigationStack {
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

                        // NavigationLink to ResultsView
                        // destination is ResultsView with mock data for now
                        NavigationLink(destination:
                            ResultsView(result: FishResult.mock(image: image))
                        ) {
                            Label("Scan Fish", systemImage: "fishscale.connected")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
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
    return PhotoPreviewView(image: fakeImage, onRetake: {})
}
