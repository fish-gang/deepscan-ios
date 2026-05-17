import SwiftUI
import SwiftData

struct DiaryDetailView: View {

    let entry: DiaryEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            OceanTheme.backgroundGradient
                .ignoresSafeArea()

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
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(OceanTheme.seafoam)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .foregroundStyle(OceanTheme.coral)
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
                Color.white.opacity(0.08)
                    .frame(height: 240)
                    .overlay(
                        Image("diver")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .opacity(0.85)
                    )
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        .accessibilityLabel("Photo of \(entry.fishName)")
    }

    // MARK: - Title + Confidence

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.fishName)
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.white)
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
            .foregroundStyle(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)

            if let location = entry.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
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
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
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
