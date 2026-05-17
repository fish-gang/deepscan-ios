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
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body)       private var subtitleSize: CGFloat = 19
    @State private var diverBob = false

    var body: some View {
        NavigationStack {
            ZStack {
                OceanTheme.backgroundGradient
                    .ignoresSafeArea()

                LightRays()
                AnimatedBubbles()
                SwimmingFishes()

                VStack(spacing: 0) {
                    Spacer()

                    // MARK: - Header
                    VStack(spacing: 14) {
                        Image("diver")
                            .resizable()
                            .scaledToFit()
                            .frame(width: diverSize, height: diverSize)
                            .rotationEffect(.degrees(diverBob ? 3 : -3))
                            .offset(y: diverBob ? -8 : 8)
                            .shadow(color: OceanTheme.aqua.opacity(0.5), radius: 24)
                            .animation(
                                .easeInOut(duration: 3.5).repeatForever(autoreverses: true),
                                value: diverBob
                            )
                            .onAppear { diverBob = true }

                        Text("DeepScan")
                            .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, OceanTheme.seafoam],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: OceanTheme.aqua.opacity(0.55), radius: 16, y: 2)
                            .tracking(-0.5)

                        Text("Identify reef fish instantly")
                            .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(0.3)
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

                    // MARK: - Secondary Navigation
                    HStack(spacing: 14) {
                        NavigationLink(destination: DiaryView()) {
                            secondaryNavLabel(icon: "book.fill", title: "Diary")
                        }
                        NavigationLink(destination: MapView()) {
                            secondaryNavLabel(icon: "map.fill", title: "Map")
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 8)
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

        // MARK: - Haptics
        .sensoryFeedback(.selection, trigger: showCamera) { _, new in new }
        .sensoryFeedback(.selection, trigger: galleryItem)
    }

    private func secondaryNavLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(OceanTheme.seafoam)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
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

// MARK: - Light Rays

// Faint diagonal "god rays" from the surface. .plusLighter brightens
// whatever sits behind so they read as light, not solid bars.
private struct LightRays: View {

    fileprivate struct Ray: Identifiable {
        let id: Int
        let x: Double         // 0...1, normalized horizontal position
        let width: CGFloat
        let height: CGFloat
        let angle: Double
        let duration: Double
        let delay: Double
        let baseOpacity: Double
    }

    private let rays: [Ray] = [
        .init(id: 0, x: 0.18, width: 90,  height: 520, angle: 14,  duration: 6.5, delay: 0,   baseOpacity: 0.10),
        .init(id: 1, x: 0.48, width: 60,  height: 600, angle: -8,  duration: 8.0, delay: 1.5, baseOpacity: 0.08),
        .init(id: 2, x: 0.78, width: 110, height: 480, angle: 22,  duration: 7.0, delay: 3.0, baseOpacity: 0.09),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ForEach(rays) { ray in
                    LightRay(ray: ray, canvasWidth: geo.size.width)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

private struct LightRay: View {

    let ray: LightRays.Ray
    let canvasWidth: CGFloat

    @State private var pulse = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(pulse ? 0.55 : 0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: ray.width, height: ray.height)
            .rotationEffect(.degrees(ray.angle))
            .opacity(ray.baseOpacity + (pulse ? 0.12 : 0))
            .position(x: canvasWidth * ray.x, y: ray.height * 0.4)
            .animation(
                .easeInOut(duration: ray.duration)
                    .repeatForever(autoreverses: true)
                    .delay(ray.delay),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}

// MARK: - Animated Bubbles

// Bubbles drift upward continuously. Each one snaps back below the screen
// after exiting the top — the snap happens off-canvas so it's invisible.
private struct AnimatedBubbles: View {

    fileprivate struct Bubble: Identifiable {
        let id: Int
        let x: Double          // 0...1, normalized horizontal position
        let size: CGFloat
        let duration: Double
        let delay: Double
        let opacity: Double
    }

    private let bubbles: [Bubble] = [
        .init(id: 0, x: 0.08, size: 14, duration: 9,  delay: 0,   opacity: 0.20),
        .init(id: 1, x: 0.20, size: 22, duration: 12, delay: 2,   opacity: 0.14),
        .init(id: 2, x: 0.32, size: 9,  duration: 7,  delay: 5,   opacity: 0.22),
        .init(id: 3, x: 0.44, size: 16, duration: 10, delay: 3,   opacity: 0.18),
        .init(id: 4, x: 0.55, size: 11, duration: 8,  delay: 6,   opacity: 0.22),
        .init(id: 5, x: 0.68, size: 18, duration: 13, delay: 1,   opacity: 0.16),
        .init(id: 6, x: 0.78, size: 8,  duration: 6,  delay: 4,   opacity: 0.24),
        .init(id: 7, x: 0.88, size: 13, duration: 11, delay: 7,   opacity: 0.20),
        .init(id: 8, x: 0.92, size: 7,  duration: 8,  delay: 9,   opacity: 0.22),
        .init(id: 9, x: 0.50, size: 10, duration: 9,  delay: 8,   opacity: 0.20),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(bubbles) { bubble in
                RisingBubble(bubble: bubble, canvasSize: geo.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct RisingBubble: View {

    let bubble: AnimatedBubbles.Bubble
    let canvasSize: CGSize

    @State private var isRising = false

    private var startY: CGFloat { canvasSize.height + 40 }
    private var endY: CGFloat   { -40 }

    var body: some View {
        Circle()
            .strokeBorder(Color.white.opacity(bubble.opacity * 1.5), lineWidth: 1)
            .background(Circle().fill(Color.white.opacity(bubble.opacity * 0.5)))
            .frame(width: bubble.size, height: bubble.size)
            .position(
                x: canvasSize.width * bubble.x,
                y: isRising ? endY : startY
            )
            .animation(
                .linear(duration: bubble.duration)
                    .repeatForever(autoreverses: false)
                    .delay(bubble.delay),
                value: isRising
            )
            .onAppear { isRising = true }
    }
}

// MARK: - Swimming Fishes

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
