import SwiftUI
import PhotosUI

struct HomeView: View {

    // MARK: - State

    // Controls whether the camera sheet is shown
    @State private var showCamera = false

    // The photo captured by camera OR picked from gallery
    // Optional because no photo exists until the user picks one
    @State private var capturedImage: UIImage? = nil

    // Controls whether the photo preview sheet is shown
    @State private var showPreview = false

    // PhotosPicker selection - this is a special type from the PhotosUI framework
    // It represents a selected item from the photo library (not the image itself yet)
    @State private var galleryItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 40) {

                    // MARK: - Header
                    VStack(spacing: 8) {
                        Text("🤿")
                            .font(.system(size: 60))

                        Text("DeepScan")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Identify fish while snorkeling")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // MARK: - Buttons
                    VStack(spacing: 16) {

                        // Camera button - opens CameraView as a full screen cover
                        Button(action: {
                            showCamera = true
                        }) {
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Gallery button - PhotosPicker is a native SwiftUI component
                        // It doesn't need a separate sheet - it's built into the label
                        // We wrap the button style around it using a label
                        PhotosPicker(
                            selection: $galleryItem,
                            matching: .images // only show photos, not videos
                        ) {
                            Label("Pick from Library", systemImage: "photo.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemFill))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 32)

                    // MARK: - Diary Navigation
                    NavigationLink(destination: Text("Diary coming soon")) {
                        Label("My Snorkel Diary", systemImage: "book.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }

        // MARK: - Camera Sheet
        // .fullScreenCover is like .sheet but covers the entire screen.
        // Better for camera since we want the live preview edge to edge.
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(capturedImage: $capturedImage)
                // Watch for a captured image - when camera delivers one, show preview
                .onChange(of: capturedImage) { _, newImage in
                    if newImage != nil {
                        showCamera = false
                        showPreview = true
                    }
                }
        }

        // MARK: - Gallery Item Handler
        // When the user picks a photo from the library, galleryItem gets set.
        // But galleryItem is just a REFERENCE to the photo, not the image itself.
        // We need to load the actual image data asynchronously.
        .onChange(of: galleryItem) { _, newItem in
            Task {
                // loadTransferable loads the actual image data from the photo library.
                // It's async because the photo might need to be downloaded from iCloud.
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                    showPreview = true
                }
            }
        }

        // MARK: - Preview Sheet
        .sheet(isPresented: $showPreview) {
            if let image = capturedImage {
                PhotoPreviewView(
                    image: image,
                    onRetake: {
                        showPreview = false
                        capturedImage = nil
                        galleryItem = nil
                        showCamera = true
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    HomeView()
}
