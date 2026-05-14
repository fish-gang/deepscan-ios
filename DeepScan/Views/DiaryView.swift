import SwiftUI
import SwiftData

struct DiaryView: View {

    @Environment(\.modelContext) private var modelContext

    // @Query replaces the manual ViewModel fetch pattern — it updates
    // the view automatically whenever the SwiftData store changes.
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    var body: some View {
        Group {
            if entries.isEmpty {

                // MARK: - Empty State
                VStack(spacing: 16) {
                    Text("🐟")
                        .font(.system(size: 64))

                    Text("No dives yet")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Scan a fish to start your underwater diary!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

            } else {

                // MARK: - Entries List
                List {
                    ForEach(entries) { entry in
                        NavigationLink(destination: DiaryDetailView(entry: entry)) {
                            DiaryRowView(entry: entry)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Snorkel Diary")
        .navigationBarTitleDisplayMode(.large)
        .tint(OceanTheme.aqua)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    // MARK: - Delete

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            entry.deleteImage()
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

// MARK: - Diary Row

struct DiaryRowView: View {

    let entry: DiaryEntry

    var body: some View {
        HStack(spacing: 12) {

            // Thumbnail photo
            Group {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemFill)
                        .overlay(
                            Image(systemName: "fish.fill")
                                .foregroundStyle(OceanTheme.aqua.opacity(0.6))
                        )
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.fishName)
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(OceanTheme.confidenceColor(entry.confidence))
                        .frame(width: 7, height: 7)
                    Text("\(Int(entry.confidence * 100))% confident")
                        .font(.subheadline)
                        .foregroundStyle(OceanTheme.confidenceColor(entry.confidence))
                }

                if let location = entry.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DiaryView()
    }
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
