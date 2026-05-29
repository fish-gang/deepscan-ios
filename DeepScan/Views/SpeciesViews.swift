import SwiftUI

// Shared presentation components for an identified fish species. Used by both
// ResultsView (a fresh scan) and DiaryDetailView (a saved entry) so the two
// screens look and behave identically.

// MARK: - Species Title

// Emoji + friendly common name with the scientific name beneath. Falls back to
// the raw model name when there's no species entry (e.g. an unknown fish).
struct SpeciesTitleView: View {
    let rawName: String

    private var species: FishSpecies? { FishSpecies.lookup(scientificName: rawName) }

    var body: some View {
        Group {
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
                Text(rawName)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Confidence Meter

// Capsule badge + progress bar, tinted by confidence. By default the bar
// animates up from zero on appear.
struct ConfidenceMeter: View {
    let confidence: Double
    var animated: Bool = true

    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.footnote.weight(.semibold))
                Text(String(format: "%.2f%% confidence", confidence * 100))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(OceanTheme.confidenceColor(confidence), in: Capsule())

            ProgressView(value: animated ? shown : confidence)
                .tint(OceanTheme.confidenceColor(confidence))
                .accessibilityLabel("Confidence")
                .accessibilityValue(String(format: "%.2f percent", confidence * 100))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard animated else { return }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.2)) {
                shown = confidence
            }
        }
    }
}

// MARK: - Species Detail Section

// The full species write-up: a featured Fun Fact, then the remaining facts
// grouped in one box, then a button that reveals the reference illustration on
// demand. Used identically by the Results and Diary screens.
struct SpeciesDetailSection: View {
    let species: FishSpecies

    private var facts: [FactItem] {
        [
            FactItem(icon: "list.bullet.indent", label: "Family",
                     text: species.family, color: OceanTheme.sunshine),
            FactItem(icon: "mappin.and.ellipse", label: "Where it's from",
                     text: species.origin, color: OceanTheme.urchin),
            FactItem(icon: "eye.fill", label: "How to spot it",
                     text: species.howToSpot, color: OceanTheme.sandy),
            FactItem(icon: "sparkles", label: "What makes it special",
                     text: species.special, color: OceanTheme.coral),
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            FeaturedFunFactCard(text: species.funFact)
                .appearIn(delay: 0.05)

            FactsBox(items: facts)
                .appearIn(delay: 0.12)

            if let illustration = species.illustration {
                ReferenceReveal(asset: illustration, commonName: species.commonName)
                    .appearIn(delay: 0.19)
            }
        }
    }
}

// MARK: - Featured Fun Fact

// The prominent hero card shown first: a gradient-framed, glowing card that
// matches the reference-illustration framing language so it reads as featured.
struct FeaturedFunFactCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(OceanTheme.sunshine)
                Text("FUN FACT")
                    .font(.caption.weight(.bold))
                    .kerning(1.4)
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [OceanTheme.seafoam, OceanTheme.aqua, OceanTheme.oceanBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: OceanTheme.aqua.opacity(0.35), radius: 18)
        .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
    }
}

// MARK: - Facts Box

// A single rounded box holding several labelled facts as rows, divided by thin
// hairlines. Used for the species facts and for the diary's own metadata.
struct FactItem {
    let icon: String
    let label: String
    let text: String
    let color: Color
}

struct FactsBox: View {
    let items: [FactItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.10))
                        .frame(height: 1)
                        .padding(.leading, 72)
                }
                FactRow(item: item)
            }
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: OceanTheme.deepOcean.opacity(0.35), radius: 10, y: 4)
    }
}

private struct FactRow: View {
    let item: FactItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.22))
                Image(systemName: item.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.color)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.label.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(.white)
                Text(item.text)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Reference Reveal

// A Show / Hide button that toggles the reference illustration inline, so it
// stays out of the way until the user wants to compare it against their photo.
struct ReferenceReveal: View {
    let asset: String
    let commonName: String

    @State private var isShown = false

    var body: some View {
        VStack(spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isShown.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                    Text(isShown ? "Hide reference illustration"
                                 : "Show reference illustration")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .rotationEffect(.degrees(isShown ? 180 : 0))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isShown {
                ReferenceCard(asset: asset, commonName: commonName)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

// MARK: - Reference Card

// The reference illustration in a frame that conforms to the artwork's own
// aspect ratio — a square illustration gets a square card, a wide one gets a
// wide card — so it never looks like a square image stuffed into a round hole.
// A bright lens backing lets both transparent cutouts (lionfish, moon wrasse)
// and white-background illustrations (clownfish, blue tang) read cleanly. The
// card gently bobs and sways like the home-screen diver.
struct ReferenceCard: View {
    let asset: String
    let commonName: String

    @State private var bob = false

    // Frame the card to the illustration's natural shape so nothing gets
    // letterboxed. Falls back to square if the asset can't be measured.
    private var aspectRatio: CGFloat {
        guard let size = UIImage(named: asset)?.size, size.height > 0 else { return 1 }
        return size.width / size.height
    }

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [.white, Color(hex: "DCEFF6")],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                    .shadow(.inner(color: OceanTheme.oceanBlue.opacity(0.18),
                                   radius: 8, x: 0, y: 2))
                )
                .overlay(
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [OceanTheme.seafoam, OceanTheme.aqua, OceanTheme.oceanBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1.5)
                )
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxWidth: 230, maxHeight: 220)
                // Bobs + sways as a whole, like the diver on the home screen.
                .rotationEffect(.degrees(bob ? 2.5 : -2.5))
                .offset(y: bob ? -5 : 5)
                .animation(
                    .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
                    value: bob
                )
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
                .shadow(color: OceanTheme.aqua.opacity(0.4), radius: 22)

            Text("Compare it with your photo above")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .onAppear { bob = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reference illustration of \(commonName). Compare it with your photo above.")
    }
}

// MARK: - Appear Animation

// Fades + lifts a block into place on appear, staggered by `delay`.
extension View {
    func appearIn(delay: Double = 0) -> some View {
        modifier(AppearIn(delay: delay))
    }
}

private struct AppearIn: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - Swimming Motion

// Gentle sway + bob driven by TimelineView so the title emoji feels alive
// without needing repeating-animation state plumbing.
struct SwimmingMotion: ViewModifier {
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
struct BubbleBackground: View {
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
