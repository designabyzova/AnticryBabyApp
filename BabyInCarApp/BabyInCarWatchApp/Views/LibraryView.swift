import SwiftUI
import WatchKit

/// Browse music library by categories on Watch
/// Plays on iPhone - Watch acts as remote control
struct LibraryView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            Group {
                if connectivityManager.libraryState.categories.isEmpty {
                    emptyStateView
                } else {
                    categoryListView
                }
            }
            .navigationTitle("Library")
        }
        .onAppear {
            // Request library sync when view appears
            connectivityManager.requestLibrarySync()
        }
    }

    // MARK: - Category List

    private var categoryListView: some View {
        List {
            // Top Calming section if available
            if !connectivityManager.libraryState.topCalmingTracks.isEmpty {
                Section {
                    Button {
                        playTopCalming()
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Top Calming")
                                    .font(.caption)
                                Text("\(connectivityManager.libraryState.topCalmingTracks.count) tracks")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Categories
            Section {
                ForEach(connectivityManager.libraryState.categories) { category in
                    CategoryRowView(category: category) {
                        playCategory(category)
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if !connectivityManager.isPhoneReachable {
                Image(systemName: "iphone.slash")
                    .font(.largeTitle)
                    .foregroundColor(.orange)

                Text("iPhone Required")
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("Connect to iPhone to browse library")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.largeTitle)
                    .foregroundColor(.blue)

                Text("Loading Library...")
                    .font(.headline)

                Button {
                    connectivityManager.requestLibrarySync()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func playCategory(_ category: WatchCategory) {
        connectivityManager.playCategory(categoryId: category.id)
        WKInterfaceDevice.current().play(.click)
    }

    private func playTopCalming() {
        // Send command to play top calming tracks
        connectivityManager.startSoothingMusic(playlistId: nil)
        WKInterfaceDevice.current().play(.click)
    }
}

// MARK: - Category Row View

struct CategoryRowView: View {
    let category: WatchCategory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(categoryColor)
                }

                // Category info
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.caption)
                        .lineLimit(1)

                    Text("\(category.trackCount) tracks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Play indicator
                Image(systemName: "play.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch category.id {
        case "Classical Music": return .purple
        case "Fairy Tales": return .pink
        case "Nature Sounds": return .green
        case "Instrumental": return .orange
        case "Children's Songs": return .blue
        case "Podcasts": return .red
        case "Lullabies": return .indigo
        case "Ambient": return .cyan
        default: return .blue
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(WatchConnectivityManager.shared)
}
