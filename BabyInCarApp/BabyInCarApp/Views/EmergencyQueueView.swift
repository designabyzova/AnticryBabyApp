// =============================================================================
// DEPRECATED: This file is deprecated as of FS-021 (Emergency Systems Consolidation)
//
// Migration: Use SmartQueueView instead of EmergencyQueueView
//
// Reason: Duplicate functionality. SmartQueueView provides superior Spotify-like UX
//         with AI reasoning cards, ambient mode, and interactive progress bar.
//
// See: ADR-0125 (Deprecation Strategy), ADR-0126 (SmartQueue Canonical System)
// =============================================================================
//
//  EmergencyQueueView.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//  Spotify-like queue view for emergency cry response
//

import SwiftUI

@available(*, deprecated, message: "Use SmartQueueView instead. See ADR-0125.")
struct EmergencyQueueView: View {
    @ObservedObject var queueManager: EmergencyQueueManager
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var showMetadataSheet = false
    @State private var selectedTrack: AudioTrack?
    @State private var showEffectivenessDialog = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header with cancel button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Emergency Mode")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let playlist = queueManager.currentPlaylist {
                            Text(playlist.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    CancelButton {
                        Task {
                            showEffectivenessDialog = true
                        }
                    }
                }
                .padding(.horizontal)

                // Session info
                HStack {
                    Label("\(queueManager.sessionDuration)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Label("\(queueManager.remainingTracksCount) remaining", systemImage: "music.note.list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Current track card
                if let currentTrack = queueManager.currentTrack {
                    CurrentTrackCard(track: currentTrack)
                        .onTapGesture {
                            selectedTrack = currentTrack
                            showMetadataSheet = true
                        }
                }

                // Progress bar - Interactive with scrubbing support
                TrackProgressBar(
                    progress: queueManager.progress,
                    currentTime: audioEngine.currentTime,
                    duration: audioEngine.duration,
                    audioEngine: audioEngine
                )
                .padding(.horizontal)

                // Upcoming tracks
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Up Next")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Queue progress indicator
                        Text("\(Int(queueManager.queueProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(queueManager.upcomingTracks.enumerated()), id: \.element.id) { index, track in
                                UpcomingTrackRow(track: track, position: index + 1)
                                    .onTapGesture {
                                        selectedTrack = track
                                        showMetadataSheet = true
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
        }
        .sheet(item: $selectedTrack) { track in
            TrackMetadataSheet(track: track)
        }
        .alert("How effective was this?", isPresented: $showEffectivenessDialog) {
            Button("Very Effective") {
                Task {
                    try? await queueManager.endSession(effective: true)
                    dismiss()
                }
            }
            Button("Somewhat Effective") {
                Task {
                    try? await queueManager.endSession(effective: true)
                    dismiss()
                }
            }
            Button("Not Effective") {
                Task {
                    try? await queueManager.endSession(effective: false)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This helps us improve playlist recommendations")
        }
    }
}

// MARK: - Preview

#Preview {
    @MainActor in
    EmergencyQueueView(queueManager: .createMock())
}
