//
//  TrackProgressBar.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//  Enhanced with interactive scrubbing support
//

import SwiftUI

/// Interactive track progress bar with drag-to-seek support
/// Can work in two modes:
/// 1. Interactive mode - with AudioEngine reference for seeking
/// 2. Display-only mode - just showing progress
struct TrackProgressBar: View {
    let progress: Double  // 0.0 - 1.0
    let currentTime: TimeInterval
    let duration: TimeInterval
    var audioEngine: AudioEngine? = nil  // Optional for interactive mode
    var interactive: Bool { audioEngine != nil }

    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: progressWidth(in: geometry), height: 8)
                        .animation(.linear(duration: 0.1), value: progress)

                    // Scrubber knob (only show in interactive mode or when dragging)
                    if interactive {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            .offset(x: progressWidth(in: geometry) - 8)
                            .scaleEffect(isDragging ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                    }
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .gesture(
                    interactive ? DragGesture(minimumDistance: 0)
                        .updating($dragOffset) { value, state, _ in
                            state = value.location.x
                        }
                        .onChanged { value in
                            isDragging = true
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let time = progress * duration
                            audioEngine?.seek(to: time)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                    : nil
                )
            }
            .frame(height: 16)

            // Time indicators
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatTime(duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        return geometry.size.width * CGFloat(max(0, min(1, progress)))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Display-only mode
        VStack(alignment: .leading, spacing: 4) {
            Text("Display Only")
                .font(.caption)
                .foregroundColor(.secondary)
            TrackProgressBar(progress: 0.25, currentTime: 45, duration: 180)
        }

        // Interactive mode (with mock AudioEngine)
        VStack(alignment: .leading, spacing: 4) {
            Text("Interactive")
                .font(.caption)
                .foregroundColor(.secondary)
            TrackProgressBar(
                progress: 0.5,
                currentTime: 90,
                duration: 180,
                audioEngine: AudioEngine.shared
            )
        }

        // Various progress states
        TrackProgressBar(progress: 0.0, currentTime: 0, duration: 180)
        TrackProgressBar(progress: 0.75, currentTime: 135, duration: 180)
        TrackProgressBar(progress: 1.0, currentTime: 180, duration: 180)
    }
    .padding()
}
