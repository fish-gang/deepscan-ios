import SwiftUI
import SwiftData

struct DiaryDetailView: View {

    let entry: DiaryEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroPhoto
                titleSection
                metadataCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(OceanTheme.aqua)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
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

    // MARK: - Hero Photo

    @ViewBuilder
    private var heroPhoto: some View {
        Group {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 360)
            } else {
                OceanTheme.backgroundGradient
                    .frame(height: 240)
                    .overlay(
                        Image(systemName: "fish.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.6))
                    )
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .accessibilityLabel("Photo of \(entry.fishName)")
    }

    // MARK: - Title + Confidence

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.fishName)
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Circle()
                    .fill(OceanTheme.confidenceColor(entry.confidence))
                    .frame(width: 8, height: 8)
                Text("\(Int(entry.confidence * 100))% confident")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OceanTheme.confidenceColor(entry.confidence))
            }

            ProgressView(value: entry.confidence)
                .tint(OceanTheme.confidenceColor(entry.confidence))
                .padding(.top, 2)
                .accessibilityLabel("Confidence")
                .accessibilityValue("\(Int(entry.confidence * 100)) percent")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                entry.date.formatted(date: .complete, time: .shortened),
                systemImage: "calendar"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if let location = entry.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notes = entry.notes {
                Label {
                    Text(notes)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "note.text")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}
