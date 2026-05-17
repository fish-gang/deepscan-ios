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

    @ScaledMetric(relativeTo: .largeTitle) private var diverSize: CGFloat = 140

    var body: some View {
        NavigationStack {
            ZStack {
                OceanTheme.backgroundGradient
                    .ignoresSafeArea()

                OceanBubbles()

                SwimmingFishes()

                VStack(spacing: 0) {
                    Spacer()

                    // MARK: - Header
                    VStack(spacing: 14) {
                        Image("diver")
                            .resizable()
                            .scaledToFit()
                            .frame(width: diverSize, height: diverSize)
                            .shadow(color: OceanTheme.aqua.opacity(0.5), radius: 24)

                        Text("DeepScan")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)

                        Text("Identify reef fish instantly")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Spacer()

                    // MARK: - Buttons
                    VStack(spacing: 14) {
                        Button(action: { showCamera = true }) {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(OceanTheme.primaryButtonGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: OceanTheme.aqua.opacity(0.45), radius: 14, y: 6)
                        }

                        PhotosPicker(selection: $galleryItem, matching: .images) {
                            Label("Pick from Library", systemImage: "photo.fill")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(.ultraThinMaterial)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 28)

                    // MARK: - Diary Navigation
                    NavigationLink(destination: DiaryView()) {
                        Label("My Snorkel Diary", systemImage: "book.fill")
                            .fontWeight(.medium)
                            .foregroundStyle(OceanTheme.seafoam)
                            .padding(.top, 28)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 40)
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

// Scattered bubble decorations that give an underwater feel.
private struct OceanBubbles: View {
    private struct Bubble: Identifiable {
        let id: Int
        let x, y, size, opacity: Double
    }

    private let bubbles: [Bubble] = [
        .init(id: 0, x: 0.08, y: 0.10, size: 14, opacity: 0.12),
        .init(id: 1, x: 0.88, y: 0.17, size: 8,  opacity: 0.15),
        .init(id: 2, x: 0.20, y: 0.33, size: 22, opacity: 0.07),
        .init(id: 3, x: 0.78, y: 0.42, size: 11, opacity: 0.13),
        .init(id: 4, x: 0.10, y: 0.58, size: 16, opacity: 0.10),
        .init(id: 5, x: 0.93, y: 0.63, size: 7,  opacity: 0.17),
        .init(id: 6, x: 0.50, y: 0.72, size: 13, opacity: 0.08),
        .init(id: 7, x: 0.30, y: 0.85, size: 9,  opacity: 0.13),
        .init(id: 8, x: 0.70, y: 0.90, size: 6,  opacity: 0.17),
        .init(id: 9, x: 0.60, y: 0.25, size: 10, opacity: 0.11),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(bubbles) { b in
                Circle()
                    .strokeBorder(Color.white.opacity(b.opacity * 1.5), lineWidth: 1)
                    .background(Circle().fill(Color.white.opacity(b.opacity * 0.5)))
                    .frame(width: b.size, height: b.size)
                    .position(x: geo.size.width * b.x, y: geo.size.height * b.y)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Ambient school of fish drifting across the home background.
// Each fish swims one direction on an independent linear loop; off-screen
// snap-back is hidden by the start/end offsets sitting beyond the bounds.
private struct SwimmingFishes: View {

    fileprivate struct Fish: Identifiable {
        let id: Int
        let y: Double          // 0...1, normalized vertical position
        let size: CGFloat
        let duration: Double   // seconds per full traversal
        let delay: Double      // stagger so fish don't move in lockstep
        let opacity: Double
        let color: Color
        let leftToRight: Bool
    }

    // Tropical reef palette — coral pinks, sandy oranges, sunny yellows,
    // chromis greens, and a touch of violet so the school reads as a school
    // and not as monochrome decoration.
    private static let palette: [Color] = [
        OceanTheme.coral,
        OceanTheme.sandy,
        OceanTheme.seagrass,
        Color(hex: "FFD23F"),   // tropical yellow
        Color(hex: "FF8C42"),   // clownfish orange
        Color(hex: "B388EB"),   // soft violet
        OceanTheme.seafoam,
    ]

    private let fishes: [Fish] = [
        .init(id: 0, y: 0.10, size: 24, duration: 18, delay: 0,   opacity: 0.55, color: palette[0], leftToRight: true),
        .init(id: 1, y: 0.18, size: 16, duration: 14, delay: 6,   opacity: 0.45, color: palette[3], leftToRight: false),
        .init(id: 2, y: 0.26, size: 20, duration: 20, delay: 2,   opacity: 0.50, color: palette[4], leftToRight: true),
        .init(id: 3, y: 0.34, size: 14, duration: 12, delay: 9,   opacity: 0.40, color: palette[5], leftToRight: false),
        .init(id: 4, y: 0.44, size: 28, duration: 24, delay: 4,   opacity: 0.45, color: palette[1], leftToRight: true),
        .init(id: 5, y: 0.54, size: 18, duration: 16, delay: 11,  opacity: 0.50, color: palette[2], leftToRight: false),
        .init(id: 6, y: 0.64, size: 22, duration: 21, delay: 7,   opacity: 0.55, color: palette[0], leftToRight: true),
        .init(id: 7, y: 0.74, size: 16, duration: 13, delay: 1,   opacity: 0.45, color: palette[6], leftToRight: false),
        .init(id: 8, y: 0.84, size: 20, duration: 19, delay: 5,   opacity: 0.50, color: palette[3], leftToRight: true),
        .init(id: 9, y: 0.92, size: 14, duration: 15, delay: 10,  opacity: 0.40, color: palette[4], leftToRight: false),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(fishes) { fish in
                SwimmingFish(fish: fish, canvasSize: geo.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct SwimmingFish: View {

    let fish: SwimmingFishes.Fish
    let canvasSize: CGSize

    @State private var isSwimming = false

    private var startX: CGFloat { fish.leftToRight ? -60 : canvasSize.width + 60 }
    private var endX: CGFloat   { fish.leftToRight ?  canvasSize.width + 60 : -60 }

    var body: some View {
        Image(systemName: "fish.fill")
            .font(.system(size: fish.size))
            .foregroundStyle(fish.color.opacity(fish.opacity))
            // SF Symbol "fish.fill" faces right by default; flip when the
            // fish is travelling right-to-left so it points where it swims.
            .scaleEffect(x: fish.leftToRight ? 1 : -1, y: 1)
            .position(
                x: isSwimming ? endX : startX,
                y: canvasSize.height * fish.y
            )
            .animation(
                .linear(duration: fish.duration)
                    .repeatForever(autoreverses: false)
                    .delay(fish.delay),
                value: isSwimming
            )
            .onAppear { isSwimming = true }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
