//
//  UpcomingTrackRow.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct UpcomingTrackRow: View {
    let track: AudioTrack
    let position: Int

    var body: some View {
        HStack(spacing: 12) {
            // Position number
            Text("\(position)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Mini album art
            AsyncImage(url: track.artworkURL.flatMap(URL.init)) { image in
                image.resizable()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let language = track.language {
                        LanguageBadge(language: language.rawValue, compact: true)
                    }
                }
            }

            Spacer()

            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground).opacity(0.7))
        .cornerRadius(12)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        UpcomingTrackRow(
            track: AudioTrack(
                title: "Ocean Waves",
                artist: "Nature Sounds",
                category: .natureSounds,
                duration: 300,
                audioSourceType: .generated,
                generatorType: .ocean
            ),
            position: 1
        )

        UpcomingTrackRow(
            track: AudioTrack(
                title: "Russian Lullaby",
                artist: "Folk Collection",
                category: .childrenSongs,
                language: .russian,
                duration: 120,
                audioSourceType: .bundled
            ),
            position: 2
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
