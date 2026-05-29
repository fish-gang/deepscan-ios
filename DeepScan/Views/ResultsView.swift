import SwiftUI
import SwiftData

struct ResultsView: View {

    let result: FishResult
    let onScanAnother: () -> Void

    // Set only when this view was pushed from FishPickerView. When present,
    // the bottom action becomes "Pick Another Fish" and pops one level back
    // to the picker (preserving the photo + boxes) instead of bouncing all
    // the way home. Nil for single-fish / whole-image classification paths.
    var onPickAnotherFish: (() -> Void)? = nil

    @State private var showSavedConfirmation = false
    @State private var showSaveSheet = false
    @State private var animatedConfidence: Double = 0

    private var isUnknown: Bool {
        result.fishName == "No fish" || result.fishName == "Unknown fish"
    }
    private var isLowConfidence: Bool { result.confidence < 0.5 && !isUnknown }
    private var canPickAnother: Bool { onPickAnotherFish != nil }
    private var species: FishSpecies? {
        FishSpecies.lookup(scientificName: result.fishName)
    }

    var body: some View {
        ZStack {
            OceanTheme.backgroundGradient
                .ignoresSafeArea()

            BubbleBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroPhoto
                    titleSection

                    if let species {
                        infoCards(for: species)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(OceanTheme.seafoam)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark", action: onScanAnother)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .sheet(isPresented: $showSaveSheet) {
            SaveDiarySheet(result: result) {
                withAnimation { showSavedConfirmation = true }
            }
            .presentationDetents([.medium])
        }
        .sensoryFeedback(.success, trigger: showSavedConfirmation) { _, new in new }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.2)) {
                animatedConfidence = result.confidence
            }
        }
    }

    // MARK: - Hero Photo

    private var heroPhoto: some View {
        Image(uiImage: result.image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            .accessibilityLabel("Photo of \(result.fishName)")
    }

    // MARK: - Title + Confidence

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let species {
                HStack(alignment: .center, spacing: 12) {
                    Text(species.emoji)
                        .font(.system(size: 44))
                        .modifier(SwimmingMotion())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(species.commonName)
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(species.scientificName)
                            .font(.subheadline.italic())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } else {
                Text(result.fishName)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.footnote.weight(.semibold))
                Text(String(format: "%.2f%% confidence", result.confidence * 100))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(OceanTheme.confidenceColor(result.confidence), in: Capsule())

            ProgressView(value: animatedConfidence)
                .tint(OceanTheme.confidenceColor(result.confidence))
                .padding(.top, 2)
                .accessibilityLabel("Confidence")
                .accessibilityValue(String(format: "%.2f percent", result.confidence * 100))

            if isLowConfidence {
                Label(
                    "Low confidence — result may not be accurate",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(OceanTheme.sandy)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    OceanTheme.sandy.opacity(0.2),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Info Cards

    @ViewBuilder
    private func infoCards(for species: FishSpecies) -> some View {
        VStack(spacing: 12) {
            InfoCard(
                icon: "list.bullet.indent",
                title: "Family",
                text: species.family,
                color: OceanTheme.sunshine,
                delay: 0.05
            )
            InfoCard(
                icon: "mappin.and.ellipse",
                title: "Where it's from",
                text: species.origin,
                color: OceanTheme.urchin,
                delay: 0.12
            )
            InfoCard(
                icon: "eye.fill",
                title: "How to spot it",
                text: species.howToSpot,
                color: OceanTheme.sandy,
                delay: 0.19
            )
            InfoCard(
                icon: "sparkles",
                title: "What makes it special",
                text: species.special,
                color: OceanTheme.coral,
                delay: 0.26
            )
            InfoCard(
                icon: "lightbulb.fill",
                title: "Fun fact",
                text: species.funFact,
                color: OceanTheme.seagrass,
                delay: 0.33
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Bottom Action Bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if isUnknown {
                Text("Species could not be identified with sufficient confidence.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            } else {
                Button {
                    showSaveSheet = true
                } label: {
                    Label(
                        showSavedConfirmation ? "Saved to Diary" : "Save to Diary",
                        systemImage: showSavedConfirmation ? "checkmark.circle.fill" : "book.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(showSavedConfirmation ? OceanTheme.seagrass : OceanTheme.aqua)
                .disabled(showSavedConfirmation)
            }

            Button(action: onPickAnotherFish ?? onScanAnother) {
                Label(
                    canPickAnother ? "Pick Another Fish" : "Scan Another Fish",
                    systemImage: "arrow.counterclockwise"
                )
                .frame(maxWidth: .infinity)
                .contentTransition(.identity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Info Card

private struct InfoCard: View {
    let icon: String
    let title: String
    let text: String
    let color: Color
    let delay: Double

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.22))
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(color)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(0.32), lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Swimming Motion

// Gentle sway + bob driven by TimelineView so the emoji feels alive without
// needing repeating-animation state plumbing.
private struct SwimmingMotion: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            content
                .rotationEffect(.degrees(sin(t * 1.4) * 6))
                .offset(y: sin(t * 1.0) * 3)
        }
    }
}

// MARK: - Bubble Background

// Animated rising bubbles drawn into a single Canvas. Positions/sizes use
// stable per-index seeds so the bubble layout doesn't reshuffle when the
// parent view re-renders.
private struct BubbleBackground: View {
    private struct Bubble {
        let x: CGFloat      // 0...1, horizontal anchor
        let size: CGFloat   // diameter in points
        let speed: Double   // seconds for a full bottom→top traversal
        let phase: Double   // 0...1, initial vertical offset
        let wobble: CGFloat // horizontal sway amplitude in points
    }

    private static let bubbles: [Bubble] = (0..<18).map { i in
        let s = Double(i)
        return Bubble(
            x: CGFloat((s * 0.137 + 0.05).truncatingRemainder(dividingBy: 1.0)),
            size: CGFloat(6 + (i % 6) * 4),
            speed: 12 + Double(i % 5) * 3.5,
            phase: (s * 0.317).truncatingRemainder(dividingBy: 1.0),
            wobble: CGFloat(6 + (i % 3) * 5)
        )
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for b in Self.bubbles {
                    let p = ((t / b.speed) + b.phase).truncatingRemainder(dividingBy: 1.0)
                    let y = size.height - (size.height + b.size * 2) * CGFloat(p)
                    let xWobble = CGFloat(sin((t + b.phase * 8) * 1.3)) * b.wobble
                    let x = b.x * size.width + xWobble
                    let rect = CGRect(
                        x: x - b.size / 2,
                        y: y - b.size / 2,
                        width: b.size,
                        height: b.size
                    )
                    let path = Path(ellipseIn: rect)
                    ctx.fill(path, with: .color(.white.opacity(0.10)))
                    ctx.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Save Diary Sheet

struct SaveDiarySheet: View {

    let result: FishResult
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var location = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Location (optional)") {
                    TextField("e.g. Great Barrier Reef", text: $location)
                }
                Section("Notes (optional)") {
                    TextField("Add a note...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .tint(OceanTheme.aqua)
            .navigationTitle("Save to Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                        onSaved()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let imagePath = DiaryEntry.storeImage(result.image)
        let entry = DiaryEntry(
            fishName: result.fishName,
            confidence: result.confidence,
            imagePath: imagePath,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 300))
        let fakeImage = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 390, height: 300))
        }
        ResultsView(result: FishResult.mock(image: fakeImage), onScanAnother: {})
    }
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
