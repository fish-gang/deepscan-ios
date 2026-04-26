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
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No dives yet")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Scan a fish and save it to start your snorkel diary!")
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
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.fishName)
                    .font(.headline)

                Text("\(Int(entry.confidence * 100))% confident")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
