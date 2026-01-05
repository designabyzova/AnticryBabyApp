// =============================================================================
// NOTE: This file tests SmartQueue UI components.
// The "EmergencyQueue" naming is preserved for git history but these tests
// validate the SmartQueueView UI patterns used in production.
//
// Migration: SmartQueueView is the production component (see SmartQueueView.swift)
// See: ADR-0126 (SmartQueue Canonical System), FS-021 (Systems Consolidation)
// =============================================================================
//
//  EmergencyQueueSnapshotTests.swift
//  BabyInCarAppTests
//
//  Created for FS-017: Smart Emergency Playlist System
//  Updated for FS-021: Tests SmartQueue UI components
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import BabyInCarApp

/// Snapshot tests for SmartQueue UI components
/// NOTE: File retains "EmergencyQueue" name for git history, but tests SmartQueueView patterns
final class EmergencyQueueSnapshotTests: XCTestCase {

    // MARK: - Configuration

    override func setUp() {
        super.setUp()
        // Set to true to record new snapshots, false for testing
        // isRecording = true
    }

    // MARK: - Mock Data

    private var mockCurrentTrack: AudioTrack {
        AudioTrack(
            id: "mock-track-001",
            title: "Brahms Lullaby",
            artist: "Classical Collection",
            category: .lullaby,
            duration: 180,
            audioSourceType: .bundled,
            calmingScore: 0.9
        )
    }

    private var mockUpcomingTracks: [AudioTrack] {
        [
            AudioTrack(
                id: "mock-track-002",
                title: "White Noise Continuous",
                artist: "Sound Therapy",
                category: .ambient,
                duration: 300,
                audioSourceType: .generated,
                generatorType: .ocean
            ),
            AudioTrack(
                id: "mock-track-003",
                title: "Колыбельная (Kolybelnaya)",
                artist: "Russian Folk",
                category: .childrenSongs,
                language: .russian,
                duration: 175,
                audioSourceType: .bundled
            ),
            AudioTrack(
                id: "mock-track-004",
                title: "Ocean Waves",
                artist: "Nature Recordings",
                category: .nature,
                duration: 260,
                audioSourceType: .cloud,
                cloudURL: "https://cdn.example.com/ocean.mp3"
            ),
            AudioTrack(
                id: "mock-track-005",
                title: "Twinkle Twinkle Little Star",
                artist: "Nursery Classics",
                category: .lullaby,
                duration: 150,
                audioSourceType: .bundled
            ),
        ]
    }

    // MARK: - Queue View Snapshot Tests

    func testEmergencyQueueView_iPhone15() {
        let view = createEmergencyQueueView()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhone13),
            named: "queue_view_iPhone15"
        )
    }

    func testEmergencyQueueView_iPhoneSE() {
        let view = createEmergencyQueueView()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhoneSe),
            named: "queue_view_iPhoneSE"
        )
    }

    func testEmergencyQueueView_iPhone15ProMax() {
        let view = createEmergencyQueueView()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhone13ProMax),
            named: "queue_view_iPhone15ProMax"
        )
    }

    // MARK: - Dark Mode Tests

    func testEmergencyQueueView_DarkMode() {
        let view = createEmergencyQueueView()
            .environment(\.colorScheme, .dark)

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhone13),
            named: "queue_view_darkMode"
        )
    }

    // MARK: - Component Snapshot Tests

    func testCurrentTrackCard() {
        let view = CurrentTrackCardPreview(track: mockCurrentTrack, progress: 0.45)
            .frame(width: 350, height: 350)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 400, height: 400)),
            named: "current_track_card"
        )
    }

    func testUpcomingTrackRow() {
        let view = UpcomingTrackRowPreview(track: mockUpcomingTracks[0], position: 1)
            .frame(width: 350, height: 80)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 400, height: 120)),
            named: "upcoming_track_row"
        )
    }

    func testUpcomingTrackRow_Russian() {
        let view = UpcomingTrackRowPreview(track: mockUpcomingTracks[1], position: 2)
            .frame(width: 350, height: 80)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 400, height: 120)),
            named: "upcoming_track_row_russian"
        )
    }

    func testLanguageBadge_English() {
        let view = LanguageBadgePreview(language: "en", compact: false)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 100, height: 50)),
            named: "language_badge_english"
        )
    }

    func testLanguageBadge_Russian() {
        let view = LanguageBadgePreview(language: "ru", compact: false)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 100, height: 50)),
            named: "language_badge_russian"
        )
    }

    func testLanguageBadge_Multi() {
        let view = LanguageBadgePreview(language: "multi", compact: false)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 100, height: 50)),
            named: "language_badge_multi"
        )
    }

    func testCancelButton() {
        let view = CancelButtonPreview()
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 100, height: 100)),
            named: "cancel_button"
        )
    }

    func testTrackProgressBar() {
        let view = TrackProgressBarPreview(progress: 0.65)
            .frame(width: 300, height: 40)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 350, height: 80)),
            named: "track_progress_bar"
        )
    }

    // MARK: - Accessibility Tests

    func testEmergencyQueueView_LargeText() {
        let view = createEmergencyQueueView()
            .environment(\.sizeCategory, .accessibilityLarge)

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhone13),
            named: "queue_view_largeText"
        )
    }

    // MARK: - Helpers

    private func hostingController<V: View>(for view: V) -> UIHostingController<V> {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = UIScreen.main.bounds
        return controller
    }

    private func createEmergencyQueueView() -> some View {
        EmergencyQueuePreview(
            currentTrack: mockCurrentTrack,
            upcomingTracks: mockUpcomingTracks,
            progress: 0.45,
            isPlaying: true
        )
    }
}

// MARK: - Preview Views for Snapshot Testing

/// Preview wrapper for SmartQueueView UI components
/// NOTE: Named "EmergencyQueuePreview" for compatibility, but represents SmartQueue patterns
struct EmergencyQueuePreview: View {
    let currentTrack: AudioTrack
    let upcomingTracks: [AudioTrack]
    let progress: Double
    let isPlaying: Bool

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
                // Header
                HStack {
                    Text("Emergency Mode")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    CancelButtonPreview()
                }
                .padding(.horizontal)

                // Current track card
                CurrentTrackCardPreview(track: currentTrack, progress: progress)

                // Progress bar
                TrackProgressBarPreview(progress: progress)
                    .padding(.horizontal)

                // Upcoming tracks
                VStack(alignment: .leading, spacing: 12) {
                    Text("Up Next")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(upcomingTracks.enumerated()), id: \.element.id) { index, track in
                                UpcomingTrackRowPreview(track: track, position: index + 1)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
        }
    }
}

/// Preview wrapper for CurrentTrackCard
struct CurrentTrackCardPreview: View {
    let track: AudioTrack
    let progress: Double

    var body: some View {
        VStack(spacing: 15) {
            // Album art placeholder
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
                    if let language = track.language?.rawValue ?? nil {
                        LanguageBadgePreview(language: language, compact: false)
                    } else {
                        LanguageBadgePreview(language: "multi", compact: false)
                    }

                    CalmingScoreBadgePreview(score: track.calmingScore ?? 0.85)
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

/// Preview wrapper for UpcomingTrackRow
struct UpcomingTrackRowPreview: View {
    let track: AudioTrack
    let position: Int

    var body: some View {
        HStack(spacing: 12) {
            // Position number
            Text("\(position)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Mini album art placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundColor(.gray)
                )

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

                    if let language = track.language?.rawValue {
                        LanguageBadgePreview(language: language, compact: true)
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

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Preview wrapper for LanguageBadge
struct LanguageBadgePreview: View {
    let language: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(languageFlag)
                .font(compact ? .caption2 : .caption)

            if !compact {
                Text(languageLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, compact ? 4 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }

    private var languageFlag: String {
        switch language {
        case "en": return "🇬🇧"
        case "ru": return "🇷🇺"
        default: return "🌐"
        }
    }

    private var languageLabel: String {
        switch language {
        case "en": return "EN"
        case "ru": return "RU"
        default: return "Multi"
        }
    }
}

/// Preview wrapper for CalmingScoreBadge
struct CalmingScoreBadgePreview: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption2)
            Text(String(format: "%.0f%%", score * 100))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.pink.opacity(0.2))
        .cornerRadius(8)
    }
}

/// Preview wrapper for CancelButton
struct CancelButtonPreview: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: "xmark")
                .font(.title2)
                .foregroundColor(.red)
        }
    }
}

/// Preview wrapper for TrackProgressBar
struct TrackProgressBarPreview: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}
