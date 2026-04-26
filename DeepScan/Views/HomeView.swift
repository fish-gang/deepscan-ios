import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var galleryItem: PhotosPickerItem? = nil

    // Each new photo gets a fresh CapturedImage with a unique id.
    // navigationDestination(item:) sees a different item every time and
    // creates a new PhotoPreviewView — preventing stale view reuse.
    @State private var previewImage: CapturedImage? = nil

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

                        Button(action: { showCamera = true }) {
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        PhotosPicker(selection: $galleryItem, matching: .images) {
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
                    NavigationLink(destination: DiaryView()) {
                        Label("My Snorkel Diary", systemImage: "book.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }

            // MARK: - Navigation to Preview
            // item: variant guarantees a fresh PhotoPreviewView for each unique
            // CapturedImage — SwiftUI keys the destination on the item's identity.
            .navigationDestination(item: $previewImage) { captured in
                PhotoPreviewView(
                    image: captured.image,
                    onRetake: {
                        previewImage = nil
                        galleryItem = nil
                        showCamera = true
                    },
                    onScanAnother: {
                        previewImage = nil
                        galleryItem = nil
                    }
                )
            }
        }

        // MARK: - Camera
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if let image = capturedImage {
                previewImage = CapturedImage(image: image)
                capturedImage = nil
            }
        }) {
            CameraView(capturedImage: $capturedImage)
        }

        // MARK: - Gallery Handler
        .onChange(of: galleryItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    previewImage = CapturedImage(image: image)
                }
            }
        }
    }
}

// Wraps UIImage with a unique identity so each capture produces a distinct
// navigation destination, preventing SwiftUI from reusing a stale view.
private struct CapturedImage: Hashable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: CapturedImage, rhs: CapturedImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    HomeView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
