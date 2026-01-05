import SwiftUI
import WatchKit

/// Shows synced favorite tracks available for playback on watch
struct FavoritesListView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    var body: some View {
        NavigationStack {
            Group {
                if connectivityManager.favorites.isEmpty {
                    emptyStateView
                } else {
                    trackListView
                }
            }
            .navigationTitle("Favorites")
        }
    }

    // MARK: - Track List

    private var trackListView: some View {
        List {
            ForEach(connectivityManager.favorites) { track in
                TrackRowView(
                    track: track,
                    isPlaying: audioPlayer.currentTrack?.id == track.id && audioPlayer.isPlaying,
                    onTap: {
                        playTrack(track)
                    }
                )
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Favorites Synced")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add favorites on your iPhone to sync them here")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !connectivityManager.isPhoneReachable {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                    Text("iPhone not connected")
                        .font(.caption2)
                }
                .padding(.top, 8)
            }

            Button {
                connectivityManager.requestStateSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Actions

    private func playTrack(_ track: WatchTrack) {
        if track.isSynced && track.localURL != nil {
            // Play locally on watch
            let syncedTracks = connectivityManager.favorites.filter { $0.isSynced }
            if let index = syncedTracks.firstIndex(where: { $0.id == track.id }) {
                audioPlayer.playPlaylist(syncedTracks, startIndex: index)
            }
        } else {
            // Request iPhone to play
            connectivityManager.playTrack(trackId: track.id)
        }

        WKInterfaceDevice.current().play(.click)
    }
}

// MARK: - Track Row View

struct TrackRowView: View {
    let track: WatchTrack
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)

                    if let artworkData = track.artworkData,
                       let _ = UIImage(data: artworkData) {
                        // Would display artwork here
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                    }

                    // Playing indicator
                    if isPlaying {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 16, y: 16)
                    }
                }

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(isPlaying ? .blue : .primary)

                    Text(track.artist)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Sync status
                if track.isSynced {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UIImage compatibility for watchOS

#if os(watchOS)
import UIKit

extension UIImage {
    convenience init?(data: Data) {
        // Note: watchOS uses UIImage from WatchKit's UIKit compatibility
        self.init()
    }
}
#endif

#Preview {
    FavoritesListView()
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(WatchAudioPlayer.shared)
}
