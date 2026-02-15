//
//  SmartSoothingQueueView.swift
//  BabyInCarApp
//
//  Queue view shown during cry-response soothing playback
//  Includes "It Helped!" and "Still Crying" feedback buttons
//  Shows AI reasoning for track selection
//

import SwiftUI
import UIKit

// MARK: - SmartSoothingQueueView

/// Queue view for cry-type-specific soothing playback
/// Shows current track, upcoming queue, and feedback buttons
struct SmartSoothingQueueView: View {
    let cryType: CryType
    let confidence: Double

    @ObservedObject private var feedbackService = FeedbackCollectionService.shared
    @ObservedObject private var autoDetector = CryStopAutoDetector.shared
    @ObservedObject private var changeDetector = CryTypeChangeDetector.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    @State private var showFeedbackConfirmation = false
    @State private var feedbackMessage = ""
    @State private var animateHeart = false
    @State private var currentCryType: CryType

    init(cryType: CryType, confidence: Double) {
        self.cryType = cryType
        self.confidence = confidence
        self._currentCryType = State(initialValue: cryType)
    }

    // Haptics
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            ScrollView {
                VStack(spacing: 24) {
                    // Header with cry type info
                    cryTypeHeader

                    // Now playing section
                    nowPlayingSection

                    // Feedback buttons section
                    feedbackSection

                    // Queue preview (always show — queue is auto-replenished to 6 upcoming)
                    upcomingSection

                    // AI reasoning
                    aiReasoningSection

                    // Cry stop progress (if detecting)
                    if autoDetector.isInQuietPeriod {
                        cryStopProgressSection
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            // Feedback confirmation toast
            if showFeedbackConfirmation {
                feedbackToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .withCryStopPrompt() // Add cry stop auto-detection overlay
        .withCryTypeChangePrompt() // Add cry type change detection overlay
        .navigationTitle("Soothing Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .onAppear {
            // Start feedback session
            feedbackService.startSession(cryType: cryType, babyAge: 6)
            // Start auto-detection
            autoDetector.startMonitoring()
            // Start cry type change detection
            changeDetector.startMonitoring(initialCryType: cryType)
        }
        .onDisappear {
            // End session if not already ended
            if feedbackService.isSessionActive {
                feedbackService.endSession(outcome: .abandoned)
            }
            autoDetector.stopMonitoring()
            changeDetector.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cryTypeChangeAccepted)) { notification in
            handleCryTypeChange(notification)
        }
    }

    // MARK: - Cry Type Change Handler

    private func handleCryTypeChange(_ notification: Notification) {
        guard let newType = notification.userInfo?["newType"] as? CryType else { return }

        let previousType = currentCryType
        currentCryType = newType

        // Update feedback session for new cry type
        let babyAge = 6 // Default age in months
        feedbackService.endSession(outcome: .cryTypeChanged)
        feedbackService.startSession(cryType: newType, babyAge: babyAge)

        // Generate new playlist for the changed cry type
        Task {
            let babyAge = 6 // Default age in months

            let newPlaylist = await SmartPlaylistBuilder.shared.buildPlaylistForCryTypeChange(
                newCryType: newType,
                previousCryType: previousType,
                babyAge: babyAge
            )

            // Replace current queue with new playlist (keeping current track playing)
            await MainActor.run {
                audioEngine.play(playlist: Playlist(name: newPlaylist.name, tracks: newPlaylist.tracks, createdAt: Date()))

                // Show feedback to user
                feedbackMessage = "Switched to \(newType.displayName) playlist"
                withAnimation(.spring()) {
                    showFeedbackConfirmation = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showFeedbackConfirmation = false
                    }
                }
            }

            print("[SmartSoothingQueueView] 🔄 Playlist switched: \(previousType.displayName) → \(newType.displayName)")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        switch currentCryType {
        case .hunger:
            return [Color(red: 0.6, green: 0.3, blue: 0.2), Color(red: 0.3, green: 0.15, blue: 0.1)]
        case .tired:
            return [Color(red: 0.3, green: 0.2, blue: 0.5), Color(red: 0.15, green: 0.1, blue: 0.3)]
        case .pain:
            return [Color(red: 0.5, green: 0.15, blue: 0.2), Color(red: 0.3, green: 0.08, blue: 0.12)]
        default:
            return [Color(red: 0.25, green: 0.25, blue: 0.4), Color(red: 0.12, green: 0.12, blue: 0.25)]
        }
    }

    // MARK: - Cry Type Header

    private var cryTypeHeader: some View {
        HStack(spacing: 12) {
            // Cry type icon
            ZStack {
                Circle()
                    .fill(cryTypeColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: currentCryType.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(cryTypeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Soothing for")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 8) {
                    Text(currentCryType.displayName)
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text("\(Int(confidence * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.15))
                        )
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var cryTypeColor: Color {
        switch currentCryType {
        case .hunger: return .orange
        case .tired: return .purple
        case .pain: return .red
        case .attention: return .blue
        case .discomfort: return .yellow
        default: return .gray
        }
    }

    // MARK: - Now Playing Section

    private var nowPlayingSection: some View {
        VStack(spacing: 16) {
            if let currentTrack = audioEngine.currentTrack {
                // Album art / icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .frame(width: 160, height: 160)

                    Image(systemName: currentTrack.category.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                // Track info
                VStack(spacing: 6) {
                    Text("NOW PLAYING")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.5))

                    Text(currentTrack.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(currentTrack.artist)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Progress bar
                if audioEngine.duration > 0 {
                    VStack(spacing: 4) {
                        ProgressView(value: audioEngine.currentTime, total: audioEngine.duration)
                            .tint(.white)

                        HStack {
                            Text(formatTime(audioEngine.currentTime))
                            Spacer()
                            Text("-\(formatTime(audioEngine.duration - audioEngine.currentTime))")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                }

                // Playback controls
                HStack(spacing: 32) {
                    // Stop button
                    Button {
                        audioEngine.stopSoothingMode()
                        dismiss()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Button {
                        audioEngine.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Button {
                        if audioEngine.playbackState == .playing {
                            audioEngine.pause()
                        } else {
                            audioEngine.resume()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 64, height: 64)

                            Image(systemName: audioEngine.playbackState == .playing ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.black)
                                .offset(x: audioEngine.playbackState == .playing ? 0 : 3)
                        }
                    }

                    Button {
                        audioEngine.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Invisible spacer to balance the stop button
                    Color.clear
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(spacing: 12) {
            Text("How is it going?")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 16) {
                // Still Crying button
                Button {
                    impactMedium.impactOccurred()
                    recordStillCrying()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "face.dashed")
                        Text("Still Crying")
                    }
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // It Helped! button
                Button {
                    notificationFeedback.notificationOccurred(.success)
                    recordItHelped()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .scaleEffect(animateHeart ? 1.2 : 1.0)
                        Text("It Helped!")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [.green, Color(red: 0.2, green: 0.7, blue: 0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }

            Text("Your feedback helps improve recommendations")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        let upcoming = audioEngine.upcomingTracks
        let displayCount = min(upcoming.count, 6)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.white.opacity(0.7))
                Text("Up Next")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if !upcoming.isEmpty {
                    Text("\(displayCount) tracks")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if upcoming.isEmpty {
                Text("Queue will replenish automatically...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(upcoming.prefix(6).enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 20)

                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.forCategory(track.category).opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: track.category.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.forCategory(track.category))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(track.formattedDuration)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }

                            Spacer()

                            // Position in queue (2/7, 3/7, etc.)
                            Text("\(index + 2)/7")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white.opacity(0.05))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - AI Reasoning Section

    private var aiReasoningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("AI Selection")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(aiReasoningText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var aiReasoningText: String {
        let babyAge = 6 // Default age in months
        var reasoning = "Selected tracks optimized for \(currentCryType.displayName.lowercased())"

        if babyAge < 6 {
            reasoning += " with gentle, rhythmic sounds perfect for newborns"
        } else if babyAge < 12 {
            reasoning += " balanced for infant comfort and engagement"
        } else {
            reasoning += " with variety suited to your toddler's preferences"
        }

        reasoning += ". Tracks are ordered by effectiveness history and category variety."

        return reasoning
    }

    // MARK: - Cry Stop Progress

    private var cryStopProgressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.blue)
                Text("Baby seems calmer...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            ProgressView(value: autoDetector.quietPeriodProgress)
                .tint(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.blue.opacity(0.15))
        )
    }

    // MARK: - Feedback Toast

    private var feedbackToast: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                Text(feedbackMessage)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .padding(.top, 60)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    private func recordItHelped() {
        // Animate heart
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            animateHeart = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateHeart = false
        }

        // Record feedback
        feedbackService.recordItHelped()

        // Record current track for effectiveness
        if let track = audioEngine.currentTrack {
            feedbackService.recordTrackPlayed(track)
        }

        // Show confirmation
        feedbackMessage = "Thanks! Saving what works"
        withAnimation(.spring()) {
            showFeedbackConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showFeedbackConfirmation = false
            }
        }
    }

    private func recordStillCrying() {
        // Record as not helped
        feedbackService.recordStillCrying()

        // Show feedback
        feedbackMessage = "We'll try different tracks"
        withAnimation(.spring()) {
            showFeedbackConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showFeedbackConfirmation = false
            }
        }

        // Skip to next track
        audioEngine.next()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SmartSoothingQueueView(
            cryType: .tired,
            confidence: 0.85
        )
        .environmentObject(AudioEngine.shared)
    }
}
