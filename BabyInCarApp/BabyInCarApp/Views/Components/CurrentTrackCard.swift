//
//  CurrentTrackCard.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct CurrentTrackCard: View {
    let track: AudioTrack

    var body: some View {
        VStack(spacing: 15) {
            // Album art (placeholder or actual image)
            AsyncImage(url: track.artworkURL.flatMap(URL.init)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 250, height: 250)
            .cornerRadius(20)
            .shadow(radius: 10)

            // Track info
            VStack(spacing: 5) {
                Text(track.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Metadata badges
                HStack(spacing: 10) {
                    if let language = track.language {
                        LanguageBadge(language: language.rawValue)
                    }

                    CalmingScoreBadge(score: track.calmingScore)
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(25)
        .shadow(radius: 15)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    CurrentTrackCard(track: AudioTrack(
        title: "Brahms Lullaby",
        artist: "Classical Collection",
        category: .classicalMusic,
        language: .english,
        duration: 180,
        calmingScore: 0.9,
        audioSourceType: .bundled
    ))
}
