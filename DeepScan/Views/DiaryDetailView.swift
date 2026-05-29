import SwiftUI
import SwiftData

struct DiaryDetailView: View {

    let entry: DiaryEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    private var species: FishSpecies? {
        FishSpecies.lookup(scientificName: entry.fishName)
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

                    FactsBox(items: metadataItems)
                        .appearIn(delay: 0.26)
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
                    .frame(maxHeight: 320)
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
            SpeciesTitleView(rawName: entry.fishName)
            ConfidenceMeter(confidence: entry.confidence)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Diary Metadata

    // The entry-specific log (when / where / notes), shown in the same combined
    // box style as the species facts so the whole screen reads as one set.
    private var metadataItems: [FactItem] {
        var items: [FactItem] = [
            FactItem(
                icon: "calendar",
                label: "Logged",
                text: entry.date.formatted(date: .complete, time: .shortened),
                color: OceanTheme.seafoam
            )
        ]
        if let location = entry.location {
            items.append(FactItem(
                icon: "mappin.and.ellipse",
                label: "Location",
                text: location,
                color: OceanTheme.aqua
            ))
        }
        if let notes = entry.notes {
            items.append(FactItem(
                icon: "note.text",
                label: "Notes",
                text: notes,
                color: OceanTheme.sandy
            ))
        }
        return items
    }
}
