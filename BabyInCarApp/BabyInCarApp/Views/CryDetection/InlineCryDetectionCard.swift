//
//  InlineCryDetectionCard.swift
//  BabyInCarApp
//
//  Beautiful compact cry detection card for HomeView
//  Shows real-time status: listening, detecting, playing
//

import SwiftUI

// MARK: - InlineCryDetectionCard

/// A beautiful, compact cry detection card that shows real-time status on the home page
struct InlineCryDetectionCard: View {
    @ObservedObject private var viewModel = CryDetectionViewModel.shared
    @EnvironmentObject var audioEngine: AudioEngine


    @State private var showingFullDetection = false

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle:
                idleCard
            case .listening:
                listeningCard
            case .detecting(let cryType, let confidence, let progress):
                detectingCard(cryType: cryType, confidence: confidence, progress: progress)
            case .detected(let cryType, let confidence):
                detectedCard(cryType: cryType, confidence: confidence)
            case .playingSoothing(let cryType, let track):
                playingCard(cryType: cryType, track: track)
            case .error(let message):
                errorCard(message: message)
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingFullDetection) {
            CryDetectionView()
                .environmentObject(audioEngine)
        }
    }

    // MARK: - Idle State Card

    private var idleCard: some View {
        Button {
            viewModel.startDetection()
        } label: {
            HStack(spacing: 16) {
                // Animated microphone icon
                ZStack {
                    // Outer gradient ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.appSecondary.opacity(0.4), Color.appPrimary.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 56, height: 56)

                    // Inner filled circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appSecondary, Color.appPrimary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)

                    // Microphone icon
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Cry Detection & Insights")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appText)

                    Text("Tap to start listening")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()

                // Start button
                Text("Start")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appSecondary, Color.appPrimary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityIdentifier("cryDetectionCard")
    }

    // MARK: - Listening State Card

    private var listeningCard: some View {
        HStack(spacing: 16) {
            // Animated listening indicator
            ZStack {
                // Pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.appSecondary.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 56 + CGFloat(index) * 16, height: 56 + CGFloat(index) * 16)
                        .scaleEffect(viewModel.pulseScale - Double(index) * 0.2)
                        .opacity(2 - viewModel.pulseScale)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: viewModel.pulseScale)
                }

                Circle()
                    .fill(Color.appSecondary.opacity(0.15))
                    .frame(width: 56, height: 56)

                // Waveform icon with simple opacity animation (iOS 16 compatible)
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.appSecondary)
                    .opacity(viewModel.pulseScale > 1.5 ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: viewModel.pulseScale)
            }
            .frame(width: 80, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("Listening...")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appText)
                }

                // Mini waveform visualization
                MiniWaveformView(level: viewModel.audioLevel)
                    .frame(height: 20)
            }

            Spacer()

            // Stop button
            Button {
                viewModel.stopDetection()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.red.opacity(0.8)))
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Detecting State Card

    private func detectingCard(cryType: CryType, confidence: Double, progress: Double) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Cry type icon
                ZStack {
                    Circle()
                        .fill(cryTypeColor(cryType).opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: cryType.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(cryTypeColor(cryType))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Detecting...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appTextSecondary)

                    HStack(spacing: 8) {
                        Text(cryType.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)

                        Text("\(Int(confidence * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(cryTypeColor(cryType))
                    }
                }

                Spacer()

                // Stop button
                Button {
                    viewModel.stopDetection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.appCardBackground))
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [cryTypeColor(cryType), cryTypeColor(cryType).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Detected State Card

    private func detectedCard(cryType: CryType, confidence: Double) -> some View {
        HStack(spacing: 16) {
            // Cry type icon with checkmark
            ZStack {
                Circle()
                    .fill(cryTypeColor(cryType).opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: cryType.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(cryTypeColor(cryType))

                // Checkmark badge
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 20, y: -20)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Detected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)

                Text(cryType.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)
            }

            Spacer()

            // Starting playlist indicator
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Starting playlist...")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Playing State Card

    private func playingCard(cryType: CryType, track: AudioTrack?) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Now playing album art / category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [cryTypeColor(cryType).opacity(0.2), cryTypeColor(cryType).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    if let track = track ?? audioEngine.currentTrack {
                        Image(systemName: track.category.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(cryTypeColor(cryType))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(cryTypeColor(cryType))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Cry type badge
                    HStack(spacing: 6) {
                        Image(systemName: cryType.iconName)
                            .font(.system(size: 10))
                        Text(cryType.displayName)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(cryTypeColor(cryType))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(cryTypeColor(cryType).opacity(0.15))
                    )

                    // Track name
                    if let track = track ?? audioEngine.currentTrack {
                        Text(track.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.appText)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 13))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Loading track...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }
                }

                Spacer()

                // Playback controls
                HStack(spacing: 12) {
                    // Play/Pause button
                    Button {
                        if audioEngine.playbackState.isPlaying {
                            audioEngine.pause()
                        } else {
                            audioEngine.resume()
                        }
                    } label: {
                        Image(systemName: audioEngine.playbackState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [cryTypeColor(cryType), cryTypeColor(cryType).opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                    }

                    // Stop/Done button
                    Button {
                        audioEngine.stop()
                        viewModel.reset()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.appCardBackground))
                    }
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(cryTypeColor(cryType))
                        .frame(width: geometry.size.width * CGFloat(audioEngine.currentTime / max(1, audioEngine.duration)), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Error State Card

    private func errorCard(message: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appText)

                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                viewModel.retryDetection()
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.appCardBackground)
            .shadow(color: Color.appSecondary.opacity(0.1), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.appSecondary.opacity(0.2), Color.appPrimary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func cryTypeColor(_ cryType: CryType) -> Color {
        switch cryType {
        case .hunger: return .orange
        case .tired: return .purple
        case .pain: return .red
        case .attention: return .blue
        case .discomfort: return .yellow
        case .general: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Mini Waveform View

/// Compact waveform visualization for the inline card
struct MiniWaveformView: View {
    let level: Float
    private let barCount = 12

    @State private var bars: [Float] = Array(repeating: 0.2, count: 12)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSecondary, Color.appPrimary],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: CGFloat(bars[index]) * 20)
            }
        }
        .onChange(of: level) { newLevel in
            updateBars(with: newLevel)
        }
        .onAppear {
            startIdleAnimation()
        }
    }

    private func updateBars(with level: Float) {
        withAnimation(.easeOut(duration: 0.1)) {
            bars.removeFirst()
            bars.append(max(0.2, min(1.0, level * 2)))
        }
    }

    private func startIdleAnimation() {
        Task {
            while !Task.isCancelled {
                if level < 0.1 {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            for i in 0..<bars.count {
                                bars[i] = Float.random(in: 0.15...0.35)
                            }
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        InlineCryDetectionCard()
            .environmentObject(AudioEngine.shared)
    }
    .padding()
    .background(Color.appBackground)
}
