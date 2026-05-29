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
                        SpeciesDetailSection(species: species)
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
            SpeciesTitleView(rawName: result.fishName)

            ConfidenceMeter(confidence: result.confidence)

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
