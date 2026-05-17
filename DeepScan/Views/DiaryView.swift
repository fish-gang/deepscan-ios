import SwiftUI
import SwiftData

struct DiaryView: View {

    @Environment(\.modelContext) private var modelContext

    // @Query replaces the manual ViewModel fetch pattern — it updates
    // the view automatically whenever the SwiftData store changes.
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    @State private var selectedEntry: DiaryEntry?

    var body: some View {
        ZStack {
            OceanTheme.backgroundGradient
                .ignoresSafeArea()

            if entries.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
        .navigationDestination(item: $selectedEntry) { entry in
            DiaryDetailView(entry: entry)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: entries.count) { old, new in
            new < old
        }
        .navigationTitle("Snorkel Diary")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(OceanTheme.seafoam)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            Image("ponyo")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            OceanTheme.deepOcean.opacity(0.4),
                            OceanTheme.deepOcean.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                Text("No dives yet")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Scan a fish to start your underwater diary!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        List {
            ForEach(entries) { entry in
                Button {
                    selectedEntry = entry
                } label: {
                    DiaryRowView(entry: entry)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
        HStack(spacing: 14) {

            // Thumbnail photo
            Group {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    OceanTheme.aqua.opacity(0.35)
                        .overlay(
                            Image("diver")
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        )
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.fishName)
                    .font(.headline)
                    .foregroundStyle(.white)

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
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                } else {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: OceanTheme.deepOcean.opacity(0.4), radius: 10, y: 4)
    }
}

#Preview {
    NavigationStack {
        DiaryView()
    }
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
