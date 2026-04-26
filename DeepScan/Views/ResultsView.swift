import SwiftUI
import SwiftData

struct ResultsView: View {

    let result: FishResult
    let onScanAnother: () -> Void

    @State private var showSavedConfirmation = false
    @State private var showSaveSheet = false

    @Environment(\.modelContext) private var modelContext

    private var isUnknown: Bool { result.fishName == "Unknown Species" }
    private var isLowConfidence: Bool { result.confidence < 0.5 && !isUnknown }

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
                        .clipped()

                    // MARK: - Content
                    VStack(spacing: 24) {

                        // Fish name + confidence
                        VStack(spacing: 8) {
                            Text(result.fishName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text("\(Int(result.confidence * 100))% confident")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ConfidenceBarView(confidence: result.confidence)

                            if isLowConfidence {
                                Label("Low confidence — result may not be accurate", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                            }
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

                            if isUnknown {
                                Text("Species could not be identified with sufficient confidence.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Button(action: { showSaveSheet = true }) {
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
                            }

                            Button(action: onScanAnother) {
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
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onScanAnother) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveDiarySheet(result: result) {
                withAnimation { showSavedConfirmation = true }
            }
            .presentationDetents([.medium])
        }
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
            .navigationTitle("Save to Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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

// MARK: - Confidence Bar

struct ConfidenceBarView: View {

    let confidence: Double

    var barColor: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geometry.size.width * confidence, height: 8)
                    .animation(.easeOut(duration: 0.6), value: confidence)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 32)
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
