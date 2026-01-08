//
//  SmartQueueView.swift
//  BabyInCarApp
//
//  World-class Spotify-like queue view for emergency cry response
//  Features: Animated queue, drag reorder, track preview, AI badges
//

import SwiftUI

struct SmartQueueView: View {
    @ObservedObject var queue: SmartEmergencyQueue
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var showStopConfirmation = false
    @State private var draggedTrack: AudioTrack?
    @State private var showTrackDetails: AudioTrack?
    @State private var animateNowPlaying = false
    @State private var isDraggingProgress = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Cry Type Identification UI
    @State private var showCryTypeSwitch = false
    @ObservedObject private var cryDetection = CryDetectionService.shared

    /// Whether this view is presented as an overlay (vs fullScreenCover)
    /// When overlay, don't call dismiss() as it would dismiss parent sheet
    var isOverlay: Bool = false

    var body: some View {
        ZStack {
            // Animated gradient background
            backgroundGradient

            // Main scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with cancel + session info
                    headerSection
                        .padding(.bottom, 16)

                    // AI Reasoning Card - Shows why these tracks were selected
                    if !queue.isAmbientMode {
                        aiReasoningCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }

                    // Cry Type Detection Banner - Shows when cry is identified with animation
                    Group {
                        if shouldShowCryTypeSwitch {
                            cryTypeDetectedBanner
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: shouldShowCryTypeSwitch)

                    // Now Playing Hero Card
                    if let current = queue.currentTrack {
                        nowPlayingHero(current)
                            .padding(.bottom, 20)
                    }

                    // Playback controls
                    playbackControls
                        .padding(.bottom, 24)

                    // Quick suggestions
                    quickSuggestionsSection
                        .padding(.bottom, 24)

                    // Queue section
                    queueSection

                    // Bottom padding
                    Spacer(minLength: 60)
                }
            }
        }
        .sheet(item: $showTrackDetails) { track in
            TrackDetailSheet(track: track, queue: queue)
        }
        .confirmationDialog(
            "End Session?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Baby calmed down") {
                Task {
                    await queue.stop(wasEffective: true)
                    // Also deactivate EmergencyCryStopService to hide the overlay
                    EmergencyCryStopService.shared.disableAIMonitoring()
                    // Only dismiss if not an overlay (overlay hides automatically when queue.isActive becomes false)
                    if !isOverlay { dismiss() }
                }
            }
            Button("Still crying") {
                Task {
                    await queue.stop(wasEffective: false)
                    // Also deactivate EmergencyCryStopService to hide the overlay
                    EmergencyCryStopService.shared.disableAIMonitoring()
                    // Only dismiss if not an overlay
                    if !isOverlay { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This helps improve future recommendations")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateNowPlaying = true
            }
        }
    }

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors(for: queue.cryType),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle animated overlay
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .scaleEffect(animateNowPlaying ? 1.2 : 1.0)
                .offset(x: -100, y: -200)
                .blur(radius: 60)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: queue.cryType)
    }

    private func gradientColors(for cryType: CryType) -> [Color] {
        if queue.isAmbientMode {
            return [Color(red: 0.1, green: 0.4, blue: 0.3), Color(red: 0.05, green: 0.25, blue: 0.2)]
        }
        switch cryType {
        case .tired:
            return [Color(red: 0.2, green: 0.15, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.25)]
        case .hunger:
            return [Color(red: 0.5, green: 0.3, blue: 0.1), Color(red: 0.3, green: 0.15, blue: 0.05)]
        case .pain:
            return [Color(red: 0.4, green: 0.15, blue: 0.2), Color(red: 0.25, green: 0.1, blue: 0.15)]
        case .discomfort:
            return [Color(red: 0.1, green: 0.3, blue: 0.35), Color(red: 0.05, green: 0.2, blue: 0.25)]
        case .attention:
            return [Color(red: 0.15, green: 0.25, blue: 0.45), Color(red: 0.1, green: 0.15, blue: 0.3)]
        default:
            return [Color(red: 0.25, green: 0.2, blue: 0.4), Color(red: 0.15, green: 0.1, blue: 0.25)]
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top row: Cancel button
            HStack {
                Spacer()

                Button {
                    Task {
                        // Stop the smart queue
                        await queue.stop(wasEffective: nil)
                        // CRITICAL: Also deactivate EmergencyCryStopService to hide the overlay
                        // The overlay condition checks: smartQueue.isActive || emergencyService.isEmergencyModeActive
                        EmergencyCryStopService.shared.disableAIMonitoring()
                        // Only dismiss if presented as fullScreenCover, not as overlay
                        if !isOverlay { dismiss() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                        Text("CANCEL")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.red)
                            .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                }
                .accessibilityIdentifier("cancelEmergencyButton")
                .accessibilityLabel("Cancel and exit")

                Spacer()
            }
            .padding(.top, 12)

            // Session info row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(queue.queueName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if queue.isAmbientMode {
                            ModeBadge(text: "AMBIENT", color: .green)
                        }
                    }

                    Text(queue.queueDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Duration badge
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(queue.formattedDuration)
                        .font(.caption.monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                // Done button
                Button {
                    showStopConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.85))
                    .cornerRadius(20)
                }
                .accessibilityLabel("Mark as done")
                .accessibilityHint("Opens feedback dialog")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - AI Reasoning Card

    private var aiReasoningCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("AI Selection Reasoning")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }

            // Cry type detection
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: queue.cryType.iconName)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    // Detected cry type
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Detected: \(queue.cryType.rawValue)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(reasoningForCryType(queue.cryType))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)
                    }

                    Spacer()
                }

                // Track selection strategy
                Divider()
                    .background(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Smart Selection Strategy:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(selectionStrategy(for: queue.cryType), id: \.self) { strategy in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.white.opacity(0.7))
                                    .frame(width: 4, height: 4)
                                Text(strategy)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    /// Get reasoning text for cry type
    private func reasoningForCryType(_ type: CryType) -> String {
        switch type {
        case .hunger:
            return "Temporarily distract with gentle, engaging melodies while you prepare feeding"
        case .tired:
            return "Progressive sleep induction with gradually slower, deeper rhythms"
        case .pain:
            return "Immediate comfort with familiar sounds + gentle melodic structure"
        case .attention:
            return "Warm, engaging sounds that provide comfort and stimulation"
        case .discomfort:
            return "Gentle, consistent sounds to ease discomfort and soothe anxiety"
        default:
            return "Adaptive mix balancing attention, calm, and comfort"
        }
    }

    /// Get selection strategy bullets
    private func selectionStrategy(for type: CryType) -> [String] {
        switch type {
        case .hunger:
            return [
                "Upbeat classical & children's songs for distraction",
                "Avoid white noise (increases agitation when hungry)",
                "Keep tempo engaging but not overstimulating"
            ]
        case .tired:
            return [
                "Start with classical, transition to lullabies",
                "Gradually slow tempo for sleep induction",
                "Include nature sounds for deep relaxation"
            ]
        case .pain:
            return [
                "Familiar, comforting sounds like heartbeat",
                "Gentle melodies with predictable patterns",
                "Avoid sudden changes that startle"
            ]
        case .attention:
            return [
                "Mix of melodic and rhythmic content",
                "Gradually increase calming elements",
                "Include familiar favorites if known"
            ]
        case .discomfort:
            return [
                "Consistent, gentle background sounds",
                "Soothing nature sounds (rain, ocean)",
                "Gradual volume adjustments for comfort"
            ]
        default:
            return [
                "Age-appropriate mix of calming sounds",
                "Adaptive selection based on real-time response",
                "Balanced progression from active to calm"
            ]
        }
    }

    // MARK: - Cry Type Detection Banner

    /// Check if we should show the cry type switch suggestion
    /// Shows when: ambient mode is active AND a definite cry is detected
    private var shouldShowCryTypeSwitch: Bool {
        // Only show in ambient mode when a cry is detected with high confidence
        guard queue.isAmbientMode else { return false }
        guard cryDetection.isCryDetected else { return false }
        guard cryDetection.confidenceLevel >= 0.7 else { return false }
        return cryDetection.cryType != .unknown && cryDetection.cryType != .general
    }

    /// The cry type detected banner with switch melody suggestion
    private var cryTypeDetectedBanner: some View {
        VStack(spacing: 14) {
            // Header with animated indicator
            HStack(spacing: 10) {
                // Animated detection pulse
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .scaleEffect(animateNowPlaying ? 1.2 : 1.0)

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 36, height: 36)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Cry Detected!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Image(systemName: cryDetection.cryType.iconName)
                            .font(.system(size: 12))
                        Text(cryDetection.cryType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("(\(Int(cryDetection.confidenceLevel * 100))% confidence)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .foregroundColor(.orange)
                }

                Spacer()
            }

            // Suggestion text
            Text("Switch to \(cryDetection.cryType.rawValue)-specific melodies for better soothing?")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 12) {
                // Switch melodies button
                Button {
                    Task {
                        await switchToDetectedCryType()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Switch Melodies")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                }

                // Keep current button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCryTypeSwitch = false
                    }
                } label: {
                    Text("Keep Current")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.15))
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                )
        )
    }

    /// Switch from ambient mode to cry-specific mode
    private func switchToDetectedCryType() async {
        let detectedType = cryDetection.cryType
        print("[SmartQueueView] 🔄 Switching to cry-specific mode: \(detectedType.rawValue)")

        // Get the preferred language from user's locale
        let language = Locale.current.language.languageCode?.identifier ?? "en"

        // Switch to SPOTIFY-STYLE cry-specific mode
        // This uses smart recommendations + auto-replenishment
        await queue.switchToSpotifyMode(
            cryType: detectedType,
            babyAge: queue.babyAge,
            language: language
        )

        // Hide the banner
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCryTypeSwitch = false
        }
    }

    // MARK: - Now Playing Hero

    private func nowPlayingHero(_ track: AudioTrack) -> some View {
        VStack(spacing: 16) {
            // Album art with glow
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: 24)
                    .fill(categoryColor(track.category).opacity(0.4))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .scaleEffect(animateNowPlaying ? 1.1 : 1.0)

                // Album card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .frame(width: 180, height: 180)

                    VStack(spacing: 12) {
                        Image(systemName: iconForCategory(track.category))
                            .font(.system(size: 56, weight: .light))
                            .foregroundColor(.white.opacity(0.9))

                        // Animated equalizer bars
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.8))
                                    .frame(width: 4, height: queue.isPlaying ? CGFloat.random(in: 8...24) : 8)
                                    .animation(
                                        .easeInOut(duration: 0.3)
                                            .repeatForever()
                                            .delay(Double(i) * 0.1),
                                        value: queue.isPlaying
                                    )
                            }
                        }
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .accessibilityIdentifier("currentTrackCard")

            // Track info
            VStack(spacing: 6) {
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                // Tags row
                HStack(spacing: 8) {
                    CategoryBadge(category: track.category)

                    if FavoritesManager.shared.isFavorite(track: track) {
                        SmallBadge(icon: "heart.fill", color: .pink)
                    }

                    if EffectivenessManager.shared.getEffectiveness(for: track.id) != nil {
                        SmallBadge(icon: "checkmark.seal.fill", color: .green)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onTapGesture {
            showTrackDetails = track
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        VStack(spacing: 16) {
            // Progress bar - Interactive with drag gesture
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(.white)
                            .frame(width: max(0, geo.size.width * queue.progress), height: 4)

                        // Scrubber dot
                        Circle()
                            .fill(.white)
                            .frame(width: isDraggingProgress ? 16 : 12, height: isDraggingProgress ? 16 : 12)
                            .offset(x: max(0, geo.size.width * queue.progress - (isDraggingProgress ? 8 : 6)))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDraggingProgress)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingProgress = true
                                let progress = min(max(0, value.location.x / geo.size.width), 1)
                                let time = progress * audioEngine.duration
                                audioEngine.seek(to: time)
                            }
                            .onEnded { _ in
                                isDraggingProgress = false
                            }
                    )
                }
                .frame(height: 16)
                .accessibilityIdentifier("trackProgressBar")

                // Time labels
                HStack {
                    Text(formatTime(audioEngine.currentTime))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Text(formatTime(audioEngine.duration))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 40)

            // Control buttons
            HStack(spacing: 48) {
                // Previous
                ControlButton(
                    icon: "backward.fill",
                    size: 24,
                    disabled: !queue.hasPrevious
                ) {
                    Task { await queue.previous() }
                }
                .accessibilityIdentifier("previousButton")
                .accessibilityLabel("Previous track")

                // Play/Pause
                Button {
                    queue.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 4)

                        Image(systemName: queue.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: queue.isPlaying ? 0 : 2)
                    }
                }
                .accessibilityIdentifier("playPauseButton")
                .accessibilityLabel(queue.isPlaying ? "Pause" : "Play")

                // Next
                ControlButton(
                    icon: "forward.fill",
                    size: 24,
                    disabled: !queue.hasNext
                ) {
                    Task { await queue.next() }
                }
                .accessibilityIdentifier("nextButton")
                .accessibilityLabel("Next track")
            }
        }
    }

    // MARK: - Quick Suggestions

    private var quickSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Quick Try")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestedMelodicTracks, id: \.id) { track in
                        QuickSuggestionCard(track: track, iconName: iconForCategory(track.category)) {
                            Task {
                                await queue.playTrackImmediately(track)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Queue Section

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Queue header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Text("Up Next")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                // Queue counter badge
                QueueCounterBadge(current: queue.currentIndex + 1, total: queue.totalTracks)
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("upNextHeader")

            // Queue list
            LazyVStack(spacing: 8) {
                ForEach(Array(queue.upcomingTracks.enumerated()), id: \.element.id) { index, track in
                    QueueTrackRow(
                        track: track,
                        position: index + 1,
                        isFavorite: FavoritesManager.shared.isFavorite(track: track),
                        isEffective: EffectivenessManager.shared.getEffectiveness(for: track.id) != nil,
                        iconName: iconForCategory(track.category)
                    ) {
                        Task {
                            await queue.skipTo(index: queue.currentIndex + index + 1)
                        }
                    } onLongPress: {
                        showTrackDetails = track
                    }
                    .accessibilityIdentifier("upcomingTrack-\(index)")
                }

                // Empty state
                if queue.upcomingTracks.isEmpty {
                    EmptyQueueState()
                }
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("upcomingTracksList")
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func iconForCategory(_ category: AudioCategory) -> String {
        switch category {
        case .classicalMusic: return "music.note.list"
        case .childrenSongs: return "music.mic"
        case .natureSounds: return "leaf.fill"
        case .instrumental: return "pianokeys"
        case .fairyTales: return "book.fill"
        case .podcasts: return "mic.fill"
        case .lullabies: return "moon.stars.fill"
        case .ambient: return "sparkles"
        }
    }

    private func categoryColor(_ category: AudioCategory) -> Color {
        switch category {
        case .classicalMusic: return .purple
        case .childrenSongs: return .pink
        case .natureSounds: return .green
        case .instrumental: return .blue
        case .fairyTales: return .orange
        case .podcasts: return .red
        case .lullabies: return .indigo
        case .ambient: return .teal
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var suggestedMelodicTracks: [AudioTrack] {
        let contentLibrary = ContentLibraryService.shared

        let featuredKeywords = [
            "Pianomoment", "Piano Moment", "Brahms Lullaby", "Calm Piano",
            "Dreamy Piano", "Moonlight Sonata", "Bach Air", "Clair De Lune"
        ]

        let bannedKeywords: Set<String> = [
            "white noise", "pink noise", "brown noise", "fan", "washer",
            "vacuum", "rain", "thunder", "storm", "shush", "womb"
        ]

        let realMelodicTracks = contentLibrary.allTracks.filter { track in
            guard track.audioSourceType == .bundled || track.audioSourceType == .streamed else { return false }
            let melodicCategories: Set<AudioCategory> = [.classicalMusic, .instrumental, .childrenSongs]
            guard melodicCategories.contains(track.category) else { return false }
            let titleLower = track.title.lowercased()
            for banned in bannedKeywords {
                if titleLower.contains(banned) { return false }
            }
            return true
        }

        var scoredTracks: [(track: AudioTrack, score: Int)] = []
        for track in realMelodicTracks {
            var score = 0
            let titleLower = track.title.lowercased()
            for (index, featured) in featuredKeywords.enumerated() {
                if titleLower.contains(featured.lowercased()) {
                    score += 1000 - (index * 50)
                    break
                }
            }
            if track.category == .classicalMusic { score += 100 }
            if track.category == .instrumental { score += 80 }
            if titleLower.contains("piano") { score += 50 }
            if titleLower.contains("lullaby") { score += 50 }
            score += Int(track.calmingScore * 30)
            if score > 0 {
                scoredTracks.append((track, score))
            }
        }

        return scoredTracks
            .sorted { $0.score > $1.score }
            .prefix(6)
            .map { $0.track }
    }
}

// MARK: - Supporting Views

struct ModeBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.9))
        .cornerRadius(8)
    }
}

struct CategoryBadge: View {
    let category: AudioCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.rawValue)
                .font(.caption2)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct SmallBadge: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.caption)
            .foregroundColor(color)
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
    }
}

struct ControlButton: View {
    let icon: String
    let size: CGFloat
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(disabled ? .white.opacity(0.3) : .white)
        }
        .disabled(disabled)
    }
}

struct QueueCounterBadge: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(current)")
                .fontWeight(.bold)
            Text("of")
                .foregroundColor(.white.opacity(0.6))
            Text("\(total)")
                .fontWeight(.bold)
        }
        .font(.subheadline)
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .accessibilityIdentifier("queueCounter")
        .accessibilityLabel("Track \(current) of \(total)")
    }
}

struct QuickSuggestionCard: View {
    let track: AudioTrack
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )

                    Image(systemName: iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                Text(formatTitle(track.title))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
            }
        }
        .accessibilityLabel("Play \(track.title)")
    }

    private func formatTitle(_ title: String) -> String {
        let cleaned = title.replacingOccurrences(of: #" [A-F0-9]{8}$"#, with: "", options: .regularExpression)
        let shortNames: [String: String] = [
            "Pianomoment": "Piano Moment",
            "Brahms Lullaby": "Brahms",
            "Moonlight Sonata": "Moonlight",
        ]
        return shortNames[cleaned] ?? cleaned.components(separatedBy: " ").prefix(2).joined(separator: " ")
    }
}

struct QueueTrackRow: View {
    let track: AudioTrack
    let position: Int
    let isFavorite: Bool
    let isEffective: Bool
    let iconName: String
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 14) {
            // Position
            Text("\(position)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)
                .accessibilityHidden(true)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)

                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.pink)
                    }
                    if isEffective {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 6) {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    Text("•")
                        .foregroundColor(.white.opacity(0.4))

                    Text(track.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Duration
            Text(track.formattedDuration)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            // Play hint
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial.opacity(isPressed ? 0.6 : 0.4))
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.1)) { isPressed = false }
                onTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
        .accessibilityLabel("\(track.title) by \(track.artist)")
        .accessibilityHint("Tap to play, hold for details")
    }
}

struct EmptyQueueState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text("Queue Complete")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))

            Text("All tracks have been played")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityIdentifier("emptyQueueState")
    }
}

// MARK: - Track Detail Sheet

struct TrackDetailSheet: View {
    let track: AudioTrack
    @ObservedObject var queue: SmartEmergencyQueue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Track art
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 160, height: 160)

                    Image(systemName: track.category.icon)
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.purple)
                }
                .padding(.top, 20)

                // Track info
                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Label(track.category.rawValue, systemImage: track.category.icon)
                        Label(track.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // Actions
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await queue.playTrackImmediately(track)
                            dismiss()
                        }
                    } label: {
                        Label("Play Now", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button {
                        FavoritesManager.shared.toggleFavorite(track: track)
                    } label: {
                        let isFav = FavoritesManager.shared.isFavorite(track: track)
                        Label(isFav ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: isFav ? "heart.fill" : "heart")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SmartQueueView(queue: SmartEmergencyQueue.shared)
}
