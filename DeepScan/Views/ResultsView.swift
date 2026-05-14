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

    @Environment(\.modelContext) private var modelContext

    private var isUnknown: Bool { result.fishName == "Unknown Species" }
    private var isLowConfidence: Bool { result.confidence < 0.5 && !isUnknown }
    private var canPickAnother: Bool { onPickAnotherFish != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroPhoto
                titleSection
                descriptionCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
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
    }

    // MARK: - Hero Photo

    private var heroPhoto: some View {
        Image(uiImage: result.image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 360)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            .accessibilityLabel("Photo of \(result.fishName)")
    }

    // MARK: - Title + Confidence

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(result.fishName)
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.footnote.weight(.semibold))
                Text("\(Int(result.confidence * 100))% confidence")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(OceanTheme.confidenceColor(result.confidence), in: Capsule())

            ProgressView(value: result.confidence)
                .tint(OceanTheme.confidenceColor(result.confidence))
                .padding(.top, 2)
                .accessibilityLabel("Confidence")
                .accessibilityValue("\(Int(result.confidence * 100)) percent")

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
                    OceanTheme.sandy.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Description

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Did you know?", systemImage: "fish.fill")
                .font(.headline)
                .foregroundStyle(OceanTheme.aqua)

            Text(result.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - Bottom Action Bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if isUnknown {
                Text("Species could not be identified with sufficient confidence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            .tint(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
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
