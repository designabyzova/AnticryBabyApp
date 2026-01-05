//
//  TrackMetadataSheet.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct TrackMetadataSheet: View {
    let track: AudioTrack
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Basic Info") {
                    MetadataRow(label: "Title", value: track.title)
                    MetadataRow(label: "Artist", value: track.artist)
                    MetadataRow(label: "Duration", value: formatDuration(track.duration))
                    if let language = track.language {
                        MetadataRow(label: "Language", value: languageName(language.rawValue))
                    }
                    MetadataRow(label: "Category", value: track.category.rawValue.capitalized)
                }

                Section("Audio Features") {
                    MetadataRow(label: "Calming Score", value: String(format: "%.1f/10", track.calmingScore * 10))
                    if track.audioSourceType == .generated, let generator = track.generatorType {
                        MetadataRow(label: "Sound Type", value: generator.rawValue.capitalized)
                    }
                }
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func languageName(_ code: String) -> String {
        switch code {
        case "en", "english": return "English"
        case "ru", "russian": return "Russian"
        case "multi", "instrumental": return "Instrumental"
        default: return code.uppercased()
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    TrackMetadataSheet(track: AudioTrack(
        title: "Brahms Lullaby",
        artist: "Classical Collection",
        category: .classicalMusic,
        language: .english,
        duration: 180,
        calmingScore: 0.9,
        audioSourceType: .bundled
    ))
}
