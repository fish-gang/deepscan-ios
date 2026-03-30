import SwiftUI

struct ResultsView: View {

    // The result to display - passed in from PhotoPreviewView
    let result: FishResult

    // Controls whether the "Saved!" confirmation shows
    @State private var showSavedConfirmation = false

    // Lets us go back to HomeView
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Photo
                    Image(uiImage: result.image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        // .clipped cuts off anything outside the frame
                        .clipped()

                    // MARK: - Content
                    VStack(spacing: 24) {

                        // Fish name + confidence
                        VStack(spacing: 8) {
                            Text(result.fishName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            // Format confidence as percentage
                            // e.g. 0.94 → "94% confident"
                            Text("\(Int(result.confidence * 100))% confident")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            // Visual confidence bar
                            ConfidenceBarView(confidence: result.confidence)
                        }

                        Divider()

                        // Fun fact / description
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Did you know?", systemImage: "lightbulb.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)

                            Text(result.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        // MARK: - Actions
                        VStack(spacing: 12) {

                            // Save to diary button
                            Button(action: {
                                saveToDiary()
                            }) {
                                Label(
                                    showSavedConfirmation ? "Saved!" : "Save to Diary",
                                    systemImage: showSavedConfirmation ? "checkmark" : "book.fill"
                                )
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(showSavedConfirmation ? Color.green : Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(showSavedConfirmation)

                            // Scan another fish
                            Button(action: {
                                dismiss()
                            }) {
                                Label("Scan Another", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.secondarySystemFill))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        // Hide the default navigation back button - we use our own
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveToDiary() {
        // Mock save for now - we'll connect SwiftData here later
        withAnimation {
            showSavedConfirmation = true
        }
    }
}

// MARK: - Confidence Bar

// A small reusable view that visualizes the confidence as a colored bar.
// Extracted into its own struct to keep ResultsView clean - this is
// a good SwiftUI habit: break complex views into smaller components.
struct ConfidenceBarView: View {

    let confidence: Double // 0.0 to 1.0

    // Computed property - calculated on the fly from confidence value.
    // Like a getter in Java.
    var barColor: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }

    var body: some View {
        GeometryReader { geometry in
            // GeometryReader gives us the actual size of the container.
            // geometry.size.width = the available width in points.
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(height: 8)

                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geometry.size.width * confidence, height: 8)
                    // .animation makes the bar animate when confidence changes
                    .animation(.easeOut(duration: 0.6), value: confidence)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 32)
    }
}

#Preview {
    // We need a NavigationStack in the preview because ResultsView
    // uses navigation features (toolbar, back button)
    NavigationStack {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 300))
        let fakeImage = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 390, height: 300))
        }
        ResultsView(result: FishResult.mock(image: fakeImage))
    }
}
