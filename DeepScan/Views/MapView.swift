import SwiftUI
import SwiftData
import MapKit

struct MapView: View {

    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    // Free-text locations from diary entries → resolved coordinates.
    // Held in-memory only; resolved on each appear. Persisting would mean
    // a schema migration, which isn't worth it for a small diary.
    @State private var resolved: [String: CLLocationCoordinate2D] = [:]
    @State private var isResolving = false

    private var pinned: [(entry: DiaryEntry, coordinate: CLLocationCoordinate2D)] {
        entries.compactMap { entry in
            guard let location = entry.location,
                  let coord = resolved[location] else { return nil }
            return (entry, coord)
        }
    }

    var body: some View {
        ZStack {
            Map {
                ForEach(pinned, id: \.entry.id) { item in
                    Marker(
                        item.entry.fishName,
                        systemImage: "fish.fill",
                        coordinate: item.coordinate
                    )
                    .tint(OceanTheme.aqua)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)

            if pinned.isEmpty && !isResolving {
                emptyOverlay
            }
        }
        .navigationTitle("Dive Map")
        .navigationBarTitleDisplayMode(.inline)
        .tint(OceanTheme.aqua)
        .task {
            await resolveEntries()
        }
    }

    // MARK: - Empty Overlay

    private var emptyOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No dive locations yet")
                .font(.headline)
            Text("Add a location when saving a diary entry to see your dives on the map.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(28)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .padding(20)
    }

    // MARK: - Location Resolution

    // CLGeocoder was deprecated in iOS 26 in favour of MapKit. MKLocalSearch
    // accepts a natural-language query and returns map items with coordinates
    // — exactly what we need for free-text locations like "Great Barrier Reef".
    private func resolveEntries() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }

        let unresolved = Set(entries.compactMap(\.location))
            .filter { resolved[$0] == nil }

        for location in unresolved {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = location

            do {
                let response = try await MKLocalSearch(request: request).start()
                // `MKMapItem.placemark` was deprecated in iOS 26 in favour of
                // the new `location` property exposing a `CLLocation` directly.
                if let coord = response.mapItems.first?.location.coordinate {
                    resolved[location] = coord
                }
            } catch {
                // Free-text inputs won't always resolve; entries without a
                // match simply don't appear on the map.
            }
        }
    }
}

#Preview {
    NavigationStack {
        MapView()
    }
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
