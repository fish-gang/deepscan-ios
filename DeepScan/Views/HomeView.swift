import SwiftUI

struct HomeView: View {

    // @State is a property wrapper - it tells SwiftUI to re-render
    // the view whenever this variable changes.
    // Think of it like a reactive variable - similar to how in Java
    // you'd notify observers when state changes, but here it's automatic.
    @State private var showCamera = false
    @State private var showGallery = false

    var body: some View {
        // NavigationStack allows us to push new screens on top of this one.
        // It's the container that enables navigation in the app.
        NavigationStack {

            // ZStack layers views on top of each other.
            // We use it here to place a background behind everything.
            ZStack {

                // Background color - fills the whole screen
                Color(.systemBackground)
                    .ignoresSafeArea() // extends behind status bar / home indicator

                // VStack arranges children vertically with 40pt spacing
                VStack(spacing: 40) {

                    // MARK: - Header
                    // MARK is just a comment marker to organize code sections
                    // (like a bookmark - visible in Xcode's jump bar)
                    VStack(spacing: 8) {
                        Text("DeepScan")
                            .font(.largeTitle)   // predefined text style
                            .fontWeight(.bold)

                        Text("Identify fish while snorkeling")
                            .font(.subheadline)
                            .foregroundStyle(.secondary) // grey color
                    }

                    // MARK: - Buttons
                    VStack(spacing: 16) {

                        // Button takes two arguments:
                        // 1. action: what happens when tapped (a closure, like a lambda in Java)
                        // 2. label: what the button looks like
                        Button(action: {
                            showCamera = true // this triggers a re-render automatically
                        }) {
                            // This is the button's visual appearance
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity) // stretch full width
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button(action: {
                            showGallery = true
                        }) {
                            Label("Pick from Library", systemImage: "photo.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemFill))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 32) // left/right margin

                    // MARK: - Diary Navigation
                    // NavigationLink pushes a new screen when tapped.
                    // destination: the screen to navigate to
                    // label: what it looks like
                    NavigationLink(destination: Text("Diary coming soon")) {
                        Label("My Snorkel Diary", systemImage: "book.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}

// This is a Preview - only exists in development, never ships in the app.
// It lets you see the UI in Xcode's canvas without running the simulator.
#Preview {
    HomeView()
}
