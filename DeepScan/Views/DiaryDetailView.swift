import SwiftUI
import SwiftData

struct DiaryDetailView: View {

    let entry: DiaryEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Photo
                Group {
                    if let image = entry.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemFill)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipped()

                // MARK: - Info
                VStack(spacing: 24) {

                    VStack(spacing: 8) {
                        Text(entry.fishName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("\(Int(entry.confidence * 100))% confident")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ConfidenceBarView(confidence: entry.confidence)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {

                        Label(
                            entry.date.formatted(date: .complete, time: .shortened),
                            systemImage: "calendar"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if let location = entry.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let notes = entry.notes {
                            Label(notes, systemImage: "note.text")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
            }
        }
        .navigationTitle(entry.fishName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                entry.deleteImage()
                modelContext.delete(entry)
                try? modelContext.save()
                dismiss()
            }
        }
    }
}
