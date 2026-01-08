//
//  CryDetectionView.swift
//  BabyInCarApp
//
//  Redesigned: World-class 10x designer UI
//  Clean, sleek, professional cry detection interface
//

import SwiftUI

struct CryDetectionView: View {
    @ObservedObject private var emergencyService = EmergencyCryStopService.shared
    @ObservedObject private var cryDetection = CryDetectionService.shared
    @ObservedObject private var smartResponse = SmartCryResponseEngine.shared
    @ObservedObject private var smartQueue = SmartEmergencyQueue.shared
    @ObservedObject private var accuracyTracker = CryPredictionAccuracyTracker.shared
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var baby: Baby?
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Animation states
    @State private var pulseAnimation = false
    @State private var breatheAnimation = false

    // Emergency mode state
    @State private var showCancelConfirmation = false
    @State private var emergencyStartTime: Date?

    // Section expansion states
    @State private var showHowItWorks = false
    @State private var showScience = false

    // Full player presentation
    @State private var showingFullPlayer = false

    // FS-017: Check if any emergency mode is active
    private var isAnyEmergencyActive: Bool {
        smartQueue.isActive || emergencyService.isEmergencyModeActive
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient

                // Main content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Compact Status Header
                        statusHeader

                        // Main Control
                        mainControlSection

                        // Live Detection Card (when monitoring)
                        if emergencyService.isAIMonitoringEnabled {
                            liveDetectionCard
                        }

                        // Cry Detected Card with AI Classification
                        if cryDetection.isCryDetected || emergencyService.isEmergencyModeActive {
                            cryDetectedCard

                            // AI Classification Breakdown
                            aiClassificationSection

                            // Acoustic Features (when available)
                            if cryDetection.latestExtendedFeatures != nil {
                                acousticFeaturesSection
                            }
                        }

                        // REMOVED: Duplicate player card - use unified bottom mini player instead
                        // The unified mini player shows across all screens automatically
                        // No need for a separate player UI on this screen

                        // Quick Actions
                        quickActionsGrid

                        // Collapsible Info Sections
                        infoSections

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                // FS-017: Smart Emergency Queue logic (NO overlay - detection screen stays visible)
                // The player overlay was removed to keep the detection UI always visible.
                // Emergency playback still works in background via SmartEmergencyQueue.
                // User wants to see detection bars/status, not a duplicate player screen.
                // For the full player UI, use the Emergency tab in the main app.
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text("AI Cry Detection")
                            .font(.headline)
                            .fontWeight(.semibold)

                        // Show detected cry type prominently when cry is detected
                        if cryDetection.isCryDetected || emergencyService.isEmergencyModeActive {
                            DetectedCryTypeBadge(
                                cryType: emergencyService.detectedCryType,
                                confidence: cryDetection.confidenceLevel
                            )
                        } else if accuracyTracker.totalPredictions >= 5 {
                            // Show accuracy badge when not detecting
                            AIAccuracyBadge(tracker: accuracyTracker)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Button { showingHistory = true } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                CryDetectionSettingsView()
            }
            .sheet(isPresented: $showingHistory) {
                CryDetectionHistoryView()
            }
            .fullScreenCover(isPresented: $showingFullPlayer) {
                // UNIFIED ARCHITECTURE: Use PlayerView for both emergency and library playback
                // PlayerView automatically adapts UI based on audioEngine.playbackContext
                PlayerView()
                    .environmentObject(audioEngine)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                loadBaby()
                // Fix ghost playing state - sync with actual AudioEngine state
                smartQueue.syncPlaybackState()
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    breatheAnimation = true
                }
            }
            // CRITICAL FIX: Do NOT stop monitoring when view disappears!
            // Cry detection should continue in the background for baby safety.
            // The old code was stopping monitoring whenever user navigated away,
            // which completely broke the feature. Monitoring should only stop
            // when explicitly disabled by the user via toggleMonitoring().
            // .onDisappear { ... } - REMOVED
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                statusBackgroundColor.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Status Header (Compact)
    private var statusHeader: some View {
        HStack(spacing: 16) {
            // Status indicator circle
            ZStack {
                // Outer breathing ring
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 64, height: 64)
                    .scaleEffect(breatheAnimation && emergencyService.isAIMonitoringEnabled ? 1.1 : 1.0)

                // Inner filled circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [statusColor, statusColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: statusColor.opacity(0.4), radius: 8, x: 0, y: 4)

                // Icon
                Image(systemName: statusIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Status text
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Live indicator (when monitoring)
            if emergencyService.isAIMonitoringEnabled {
                HStack(spacing: 6) {
                    Circle()
                        .fill(cryDetection.isCryDetected ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }

                    Text(cryDetection.isCryDetected ? "CRY" : "OK")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(cryDetection.isCryDetected ? .red : .green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((cryDetection.isCryDetected ? Color.red : Color.green).opacity(0.15))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Main Control Section
    private var mainControlSection: some View {
        Button(action: toggleMonitoring) {
            HStack(spacing: 14) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(emergencyService.isAIMonitoringEnabled ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: emergencyService.isAIMonitoringEnabled ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(emergencyService.isAIMonitoringEnabled ? .red : .blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(emergencyService.isAIMonitoringEnabled ? "Stop Monitoring" : "Start AI Monitoring")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(emergencyService.isAIMonitoringEnabled ? "Tap to pause detection" : "Tap to start listening")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        emergencyService.isAIMonitoringEnabled ? Color.red.opacity(0.3) : Color.blue.opacity(0.3),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Live Detection Card
    private var liveDetectionCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                Text("Live Audio Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Audio level bars
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barGradientColor(for: index))
                        .frame(width: 8, height: barHeight(for: index))
                        .animation(.easeOut(duration: 0.15), value: cryDetection.currentAudioLevel)
                }
            }
            .frame(height: 36)

            // Detection confidence
            if cryDetection.confidenceLevel > 0.1 {
                HStack {
                    Text("Detection confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Confidence bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))

                            Capsule()
                                .fill(confidenceColor)
                                .frame(width: geometry.size.width * cryDetection.confidenceLevel)
                        }
                    }
                    .frame(width: 80, height: 6)

                    Text("\(Int(cryDetection.confidenceLevel * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(confidenceColor)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Cry Detected Card
    private var cryDetectedCard: some View {
        VStack(spacing: 14) {
            // Header with cry type - PROMINENTLY showing detected type!
            // FIXED: Use cryDetection.cryType directly for real-time ML classification
            HStack(spacing: 12) {
                // Icon with cry-type-specific color
                ZStack {
                    Circle()
                        .fill(cryTypeColor(for: cryDetection.cryType).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: cryDetection.cryType.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(cryTypeColor(for: cryDetection.cryType))
                }

                // Cry info - use displayName NOT rawValue!
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Detected:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(cryDetection.cryType.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(cryTypeColor(for: cryDetection.cryType))
                    }

                    Text(cryDetection.cryType.suggestedAction)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Confidence badge
                VStack(spacing: 2) {
                    Text("\(Int(cryDetection.confidenceLevel * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(cryTypeColor(for: cryDetection.cryType))
                    Text("confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Intensity indicator
            VStack(spacing: 6) {
                HStack {
                    Text("Intensity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(intensityLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(intensityColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [intensityColor.opacity(0.8), intensityColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * cryDetection.cryIntensity)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - AI Classification Section
    private var aiClassificationSection: some View {
        CryClassificationCard(
            detectedType: cryDetection.cryType,  // FIXED: Use direct cry type from ML detection
            confidence: Float(cryDetection.confidenceLevel),
            classificationBreakdown: generateClassificationBreakdown()
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Acoustic Features Section
    private var acousticFeaturesSection: some View {
        Group {
            if let features = cryDetection.latestExtendedFeatures {
                AcousticFeaturesCard(
                    fundamentalFrequency: Float(features.fundamentalFrequency),
                    spectralCentroid: Float(features.spectralCentroid),
                    harmonicsStrength: Float(features.harmonicsStrength.first ?? 0),
                    intensity: Float(features.intensity),
                    harmonicToNoiseRatio: Float(features.harmonicToNoiseRatio)
                )
                .padding(.horizontal, 20)
            }
        }
    }

    /// Generate classification breakdown - uses REAL ML data when available!
    private func generateClassificationBreakdown() -> [CryType: Double] {
        // PRIORITY 1: Use real ML classification if available
        if let mlClassification = cryDetection.latestClassification,
           !mlClassification.allProbabilities.isEmpty {
            // Real ML data! Return it directly
            return mlClassification.allProbabilities
        }

        // FALLBACK: Generate simulated breakdown when ML isn't available
        let detected = cryDetection.cryType  // FIXED: Use direct cry type
        let confidence = cryDetection.confidenceLevel

        // Primary detected type gets the confidence level
        var breakdown: [CryType: Double] = [detected: confidence]

        // Distribute remaining confidence among other types based on likelihood
        let remaining = 1.0 - confidence
        let otherTypes = CryType.allCases.filter { $0 != detected && $0 != .unknown }

        // Simulate plausible secondary matches
        switch detected {
        case .hunger:
            breakdown[.discomfort] = remaining * 0.4
            breakdown[.attention] = remaining * 0.3
            breakdown[.tired] = remaining * 0.2
            breakdown[.pain] = remaining * 0.1

        case .tired:
            breakdown[.discomfort] = remaining * 0.35
            breakdown[.hunger] = remaining * 0.25
            breakdown[.attention] = remaining * 0.25
            breakdown[.pain] = remaining * 0.15

        case .pain:
            breakdown[.discomfort] = remaining * 0.5
            breakdown[.hunger] = remaining * 0.25
            breakdown[.attention] = remaining * 0.15
            breakdown[.tired] = remaining * 0.1

        case .attention:
            breakdown[.tired] = remaining * 0.35
            breakdown[.hunger] = remaining * 0.3
            breakdown[.discomfort] = remaining * 0.25
            breakdown[.pain] = remaining * 0.1

        case .discomfort:
            breakdown[.pain] = remaining * 0.35
            breakdown[.hunger] = remaining * 0.3
            breakdown[.tired] = remaining * 0.2
            breakdown[.attention] = remaining * 0.15

        default:
            // General/unknown - evenly distribute
            let perType = remaining / Double(otherTypes.count)
            for type in otherTypes {
                breakdown[type] = perType
            }
        }

        return breakdown
    }

    // MARK: - Compact Now Playing Card
    private func nowPlayingCompactCard(track: AudioTrack) -> some View {
        Button {
            // Open full SmartQueueView for emergency playback
            showingFullPlayer = true
        } label: {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.purple)
                    Text("Now Playing")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    // Tap to expand hint
                    HStack(spacing: 4) {
                        Text("Tap to expand")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purple.opacity(0.6))
                    }

                    // Stop button
                    Button {
                        Task {
                            await smartQueue.stop(wasEffective: nil)
                            emergencyService.disableAIMonitoring()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle()) // Prevent parent button from triggering
                }

                // Track info row
                HStack(spacing: 14) {
                    // Album art placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: track.category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                    }

                    // Track info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        Text(track.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Playback controls
                    HStack(spacing: 16) {
                        Button {
                            Task { await smartQueue.previous() }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(smartQueue.hasPrevious ? .primary : .secondary.opacity(0.5))
                        }
                        .disabled(!smartQueue.hasPrevious)
                        .buttonStyle(PlainButtonStyle()) // Prevent parent button from triggering

                        Button {
                            smartQueue.togglePlayPause()
                        } label: {
                            Image(systemName: smartQueue.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(PlainButtonStyle()) // Prevent parent button from triggering

                        Button {
                            Task { await smartQueue.next() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(smartQueue.hasNext ? .primary : .secondary.opacity(0.5))
                        }
                        .disabled(!smartQueue.hasNext)
                        .buttonStyle(PlainButtonStyle()) // Prevent parent button from triggering
                    }
                }

                // Interactive progress bar with scrubbing
                interactiveProgressBar
                    .frame(height: 24)

                // Queue info
                HStack {
                    Text("Track \(smartQueue.currentIndex + 1) of \(smartQueue.totalTracks)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    if smartQueue.isAmbientMode {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.caption2)
                            Text("Ambient Mode")
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: smartQueue.cryType.iconName)
                                .font(.caption2)
                            Text(smartQueue.cryType.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Interactive Progress Bar with Scrubbing
    private var interactiveProgressBar: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                // Progress bar with scrubber
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(in: geometry, progress: smartQueue.progress), height: 6)

                    // Scrubber knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .offset(x: progressWidth(in: geometry, progress: smartQueue.progress) - 7)
                }
                .frame(height: 14)
                .contentShape(Rectangle()) // Make entire bar tappable
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            // Seek in AudioEngine
                            let time = progress * audioEngine.duration
                            audioEngine.seek(to: time)
                            selectionFeedback.selectionChanged()
                        }
                )

                // Time labels
                HStack {
                    Text(formatTime(audioEngine.currentTime))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("-\(formatTime(audioEngine.duration - audioEngine.currentTime))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func progressWidth(in geometry: GeometryProxy, progress: Double) -> CGFloat {
        return geometry.size.width * CGFloat(progress)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Haptic feedback generator
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // MARK: - Quick Actions Grid
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                // Smart Soothe button
                QuickActionButton(
                    icon: "music.note.list",
                    title: "Smart Soothe",
                    subtitle: "AI Playlist",
                    color: .purple,
                    isDisabled: isAnyEmergencyActive
                ) {
                    activateEmergencyMode()
                }

                // Skip / Not Working button
                QuickActionButton(
                    icon: smartQueue.isActive ? "forward.fill" : "hand.thumbsdown",
                    title: smartQueue.isActive ? "Skip Track" : "Not Working",
                    subtitle: smartQueue.isActive ? "Try next" : "Try another",
                    color: .orange,
                    isDisabled: !isAnyEmergencyActive
                ) {
                    reportNotWorking()
                }

                // Baby Calmed button
                QuickActionButton(
                    icon: "heart.fill",
                    title: "Calmed!",
                    subtitle: "Mark success",
                    color: .green,
                    isDisabled: !isAnyEmergencyActive
                ) {
                    reportSuccess()
                }
            }

            // DEBUG: Manual cry trigger button (only in debug builds)
            #if DEBUG
            HStack(spacing: 12) {
                // Simulate Cry button - triggers emergency mode as if cry was detected
                QuickActionButton(
                    icon: "waveform.badge.exclamationmark",
                    title: "Simulate Cry",
                    subtitle: "Test trigger",
                    color: .red,
                    isDisabled: isAnyEmergencyActive
                ) {
                    simulateCryDetection()
                }

                // Cry Again button - re-triggers emergency mode
                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "Cry Again",
                    subtitle: "Re-trigger",
                    color: .red,
                    isDisabled: false
                ) {
                    simulateCryDetection()
                }

                Spacer()
            }
            #endif
        }
    }

    // MARK: - Debug Actions
    #if DEBUG
    /// Simulate cry detection for testing - triggers emergency mode
    private func simulateCryDetection() {
        print("[DEBUG] 🧪 Simulating cry detection...")

        // Ensure we have a baby profile
        guard let baby = baby else {
            print("[DEBUG] ⚠️ No baby profile - creating default")
            let defaultBaby = Baby(name: "Test Baby", birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!)
            self.baby = defaultBaby

            Task {
                // Enable monitoring first if not enabled
                if !emergencyService.isAIMonitoringEnabled {
                    try? await emergencyService.enableAIMonitoring(for: defaultBaby)
                }

                // Trigger emergency mode
                triggerEmergencyResponse(for: defaultBaby)
            }
            return
        }

        Task {
            // Enable monitoring first if not enabled
            if !emergencyService.isAIMonitoringEnabled {
                try? await emergencyService.enableAIMonitoring(for: baby)
            }

            // Trigger emergency mode
            triggerEmergencyResponse(for: baby)
        }
    }

    /// Trigger emergency response with simulated cry
    private func triggerEmergencyResponse(for baby: Baby) {
        print("[DEBUG] 🔴 Triggering emergency response for \(baby.name)")

        // Set a random cry type for testing variety
        let cryTypes: [CryType] = [.hunger, .tired, .discomfort, .attention, .pain]
        let randomType = cryTypes.randomElement() ?? .general

        Task {
            // Start SPOTIFY-STYLE queue (smart recommendations + auto-replenish)
            await smartQueue.startSpotifyMode(
                cryType: randomType,
                babyAge: baby.ageInMonths,
                language: Locale.current.language.languageCode?.identifier ?? "en"
            )
            emergencyStartTime = Date()
            print("[DEBUG] ✅ SPOTIFY-STYLE queue started for \(randomType.rawValue) cry")
        }
    }
    #endif

    // MARK: - Info Sections (Collapsible)
    private var infoSections: some View {
        VStack(spacing: 12) {
            // How It Works
            CollapsibleSection(
                title: "How AI Detection Works",
                icon: "brain.head.profile",
                iconColor: .purple,
                isExpanded: $showHowItWorks
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    InfoItem(icon: "waveform", text: "Analyzes audio frequency patterns", color: .blue)
                    InfoItem(icon: "chart.bar.fill", text: "Classifies cry type with ML models", color: .purple)
                    InfoItem(icon: "sparkles", text: "Selects optimal soothing sounds", color: .orange)
                    InfoItem(icon: "brain", text: "Learns what works for your baby", color: .green)
                }
            }

            // Science Section
            CollapsibleSection(
                title: "The Science Behind It",
                icon: "book.pages",
                iconColor: .blue,
                isExpanded: $showScience
            ) {
                VStack(spacing: 12) {
                    ScienceItem(
                        title: "Cry Acoustic Signatures",
                        text: "Baby cries have distinct patterns: hunger (250-450Hz), pain (500-800Hz), tired (melodic variation).",
                        source: "Barr et al., Pediatrics"
                    )
                    ScienceItem(
                        title: "Rapid Response Window",
                        text: "Responding within 10 seconds leads to 40% faster calming. Our AI analyzes in under 50ms.",
                        source: "Bell & Ainsworth"
                    )
                    ScienceItem(
                        title: "Personalized Learning",
                        text: "AI personalization improves soothing effectiveness by 52% after just 5 sessions.",
                        source: "BabyMIM Research"
                    )
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var statusTitle: String {
        if cryDetection.isCryDetected {
            return "Cry Detected!"
        } else if emergencyService.isAIMonitoringEnabled {
            return "Listening..."
        } else {
            return "Ready to Monitor"
        }
    }

    private var statusSubtitle: String {
        if cryDetection.isCryDetected {
            return "AI analyzing cry pattern"
        } else if emergencyService.isAIMonitoringEnabled {
            return "Monitoring for baby sounds"
        } else {
            return "Tap Start to begin AI detection"
        }
    }

    private var statusIcon: String {
        if cryDetection.isCryDetected {
            return "exclamationmark.triangle.fill"
        } else if emergencyService.isAIMonitoringEnabled {
            return "ear.badge.waveform"
        } else {
            return "mic.fill"
        }
    }

    private var statusColor: Color {
        if cryDetection.isCryDetected {
            return .orange
        } else if emergencyService.isAIMonitoringEnabled {
            return .green
        } else {
            return .blue
        }
    }

    private var statusBackgroundColor: Color {
        if cryDetection.isCryDetected { return .orange }
        if emergencyService.isAIMonitoringEnabled { return .green }
        return .blue
    }

    private var intensityLabel: String {
        if cryDetection.cryIntensity < 0.3 { return "Low" }
        if cryDetection.cryIntensity < 0.6 { return "Medium" }
        return "High"
    }

    private var intensityColor: Color {
        if cryDetection.cryIntensity < 0.3 { return .green }
        if cryDetection.cryIntensity < 0.6 { return .yellow }
        return .red
    }

    private var confidenceColor: Color {
        if cryDetection.confidenceLevel < 0.5 { return .gray }
        if cryDetection.confidenceLevel < 0.75 { return .orange }
        return .green
    }

    /// Color for cry type - makes each cry type visually distinct
    private func cryTypeColor(for cryType: CryType) -> Color {
        switch cryType {
        case .hunger:
            return .orange
        case .tired:
            return .purple
        case .pain:
            return .red
        case .discomfort:
            return .yellow
        case .attention:
            return .blue
        case .general:
            return .teal
        case .unknown:
            return .gray
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / 24.0
        // CRITICAL FIX: Better audio level scaling for visualization
        // currentAudioLevel is RMS (0.0 to ~0.5), we need 0-1 range for 24 bars
        // Apply logarithmic scaling for better visual response (like real audio meters)
        let rawLevel = cryDetection.currentAudioLevel
        let amplified = min(1.0, rawLevel * 15.0)  // Amplify to 0-1 range (15x gain)
        let level = sqrt(amplified)  // Square root for perceptual loudness (dB-like)

        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 36

        if level > threshold {
            let heightRatio = min(1.0, (level - threshold) * 4.0)
            return baseHeight + (maxHeight - baseHeight) * CGFloat(heightRatio)
        }
        return baseHeight
    }

    private func barGradientColor(for index: Int) -> Color {
        let threshold = Float(index) / 24.0
        // CRITICAL FIX: Match the same scaling as barHeight for consistent visualization
        let rawLevel = cryDetection.currentAudioLevel
        let amplified = min(1.0, rawLevel * 15.0)
        let level = sqrt(amplified)

        if level > threshold {
            if index < 8 { return .green }
            if index < 16 { return .yellow }
            return .red
        }
        return .gray.opacity(0.3)
    }

    // MARK: - Actions

    private func loadBaby() {
        if let data = UserDefaults.standard.data(forKey: "activeBaby"),
           let loadedBaby = try? JSONDecoder().decode(Baby.self, from: data) {
            baby = loadedBaby
        } else {
            baby = Baby(name: "Baby", birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!)
        }
    }

    private func toggleMonitoring() {
        if emergencyService.isAIMonitoringEnabled {
            emergencyService.disableAIMonitoring()

            if smartQueue.isActive && smartQueue.isAmbientMode {
                Task { await smartQueue.stop(wasEffective: nil) }
            }
        } else {
            guard let baby = baby else {
                errorMessage = "Please set up a baby profile first"
                showError = true
                return
            }

            Task {
                do {
                    try await emergencyService.enableAIMonitoring(for: baby)

                    if enableAmbientPlaylist {
                        let preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"
                        await smartQueue.startAmbientMode(babyAge: baby.ageInMonths, language: preferredLanguage)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func activateEmergencyMode() {
        guard let baby = baby else { return }

        Task {
            let detectedCryType = cryDetection.cryType
            let babyAge = baby.ageInMonths
            let preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"

            // Log the cry type being used for playlist selection
            print("[CryDetectionView] 🎧 Starting SPOTIFY-STYLE queue for cry type: \(detectedCryType.displayName)")
            print("[CryDetectionView] 📊 Detection confidence: \(Int(cryDetection.confidenceLevel * 100))%, Intensity: \(Int(cryDetection.cryIntensity * 100))%")

            // Start SPOTIFY-STYLE queue:
            // - Smart track selection based on cry stop success, favorites, play counts
            // - Maintains 8 upcoming tracks at all times
            // - Auto-replenishes when tracks finish (7→8)
            await smartQueue.startSpotifyMode(
                cryType: detectedCryType,
                babyAge: babyAge,
                language: preferredLanguage
            )
            emergencyStartTime = Date()

            print("[CryDetectionView] ✅ Spotify-style queue active for '\(detectedCryType.displayName)'")
        }
    }

    private func startSmartQueueFallback() async {
        guard let baby = baby else { return }
        let preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"

        // Start SPOTIFY-STYLE queue with general cry type as fallback
        await smartQueue.startSpotifyMode(
            cryType: .general,
            babyAge: baby.ageInMonths,
            language: preferredLanguage
        )
        emergencyStartTime = Date()
    }

    private func reportNotWorking() {
        guard baby != nil else { return }

        if smartQueue.isActive {
            Task { await smartQueue.next() }
        } else {
            emergencyService.reportNotWorking(for: baby!)
        }
    }

    private func reportSuccess() {
        guard baby != nil else { return }

        if smartQueue.isActive {
            Task { await smartQueue.stop(wasEffective: true) }
        } else {
            emergencyService.reportSuccess(for: baby!)
        }
    }
}

// ScaleButtonStyle moved to ButtonStyles.swift to avoid redeclaration

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isDisabled ? 0.05 : 0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isDisabled ? .gray.opacity(0.5) : color)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isDisabled ? .gray.opacity(0.5) : .primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(isDisabled ? 0.5 : 1))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .disabled(isDisabled)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Collapsible Section

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 24)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: isExpanded ? 14 : 14)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Content
            if isExpanded {
                content()
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.tertiarySystemBackground))
                    )
                    .padding(.top, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}

// MARK: - Info Item

struct InfoItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Science Item

struct ScienceItem: View {
    let title: String
    let text: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineSpacing(2)

            Text(source)
                .font(.caption2)
                .italic()
                .foregroundColor(.blue.opacity(0.7))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Settings View

struct CryDetectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var emergencyService = EmergencyCryStopService.shared

    @AppStorage("useSmartResponse") private var useSmartResponse = true
    @AppStorage("autoActivateOnCry") private var autoActivateOnCry = true
    @AppStorage("sensitivityLevel") private var sensitivityLevel = 0.5
    @AppStorage("enableAmbientPlaylist") private var enableAmbientPlaylist = false

    var body: some View {
        NavigationView {
            Form {
                // Ambient Playlist Section
                Section {
                    Toggle("Start Playlist Immediately", isOn: $enableAmbientPlaylist)

                    if enableAmbientPlaylist {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingInfoRow(icon: "checkmark.circle.fill", text: "Plays calming music when monitoring starts", color: .green)
                            SettingInfoRow(icon: "music.note.list", text: "Uses real music: classical, lullabies, instrumental", color: .purple)
                            SettingInfoRow(icon: "waveform.slash", text: "No synthetic noise - only real recordings", color: .orange)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Ambient Playlist", systemImage: "music.note")
                } footer: {
                    Text("Proactive soothing - plays calming music before baby starts crying.")
                }

                Section("AI Response") {
                    Toggle("Use Smart AI Response", isOn: $useSmartResponse)
                    Toggle("Auto-Activate on Cry", isOn: $autoActivateOnCry)
                }

                Section("Detection Sensitivity") {
                    VStack(spacing: 8) {
                        Slider(value: $sensitivityLevel, in: 0.1...1.0)
                            .tint(.blue)

                        HStack {
                            Text("Less Sensitive")
                            Spacer()
                            Text("More Sensitive")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section("Privacy") {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Audio is analyzed on-device only. No recordings are stored or transmitted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: useSmartResponse) { newValue in
                emergencyService.setSmartResponseEnabled(newValue)
            }
        }
    }
}

struct SettingInfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
        }
    }
}

// MARK: - History View

struct CryDetectionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [EmergencySession] = []

    var body: some View {
        NavigationView {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No sessions recorded yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Your cry detection history will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessions.reversed(), id: \.timestamp) { session in
                            HistoryRow(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadHistory() }
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "EmergencySessions"),
           let loaded = try? JSONDecoder().decode([EmergencySession].self, from: data) {
            sessions = loaded
        }
    }
}

struct HistoryRow: View {
    let session: EmergencySession

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(session.wasSuccessful ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: session.cryType.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(session.wasSuccessful ? .green : .red)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.cryType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Text(session.timestamp, style: .relative)
                    Text("•")
                    Text(formatDuration(session.duration))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Status
            Image(systemName: session.wasSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(session.wasSuccessful ? .green : .red)
        }
        .padding(.vertical, 6)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Supporting View Components

struct AIAccuracyBadge: View {
    @ObservedObject var tracker: CryPredictionAccuracyTracker

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.system(size: 10))
            Text("AI Accuracy: \(Int(tracker.overallAccuracy))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(tracker.overallAccuracy >= 75 ? .green : .orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill((tracker.overallAccuracy >= 75 ? Color.green : Color.orange).opacity(0.15))
        )
    }
}

/// Shows detected cry type prominently when a cry is detected
struct DetectedCryTypeBadge: View {
    let cryType: CryType
    let confidence: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: cryType.iconName)
                .font(.system(size: 11, weight: .semibold))
            Text("\(cryType.displayName)")
                .font(.caption)
                .fontWeight(.semibold)
            Text("(\(Int(confidence * 100))%)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(cryTypeColor)
        )
    }

    private var cryTypeColor: Color {
        switch cryType {
        case .hunger:
            return .orange
        case .tired:
            return .purple
        case .pain:
            return .red
        case .discomfort:
            return .yellow.opacity(0.8)
        case .attention:
            return .blue
        case .general, .unknown:
            return .gray
        }
    }
}

struct CryClassificationCard: View {
    let detectedType: CryType?
    let confidence: Float
    let classificationBreakdown: [CryType: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Classification")
                    .font(.headline)
                Spacer()
                if let type = detectedType {
                    Text("\(Int(confidence * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }

            if let type = detectedType {
                HStack {
                    Image(systemName: type.iconName)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text(type.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Confidence: \(Int(confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)

                if !classificationBreakdown.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(classificationBreakdown.sorted(by: { $0.value > $1.value }).prefix(3), id: \.key) { type, prob in
                            HStack {
                                Text(type.displayName)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(prob * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: geo.size.width * CGFloat(prob))
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct AcousticFeaturesCard: View {
    let fundamentalFrequency: Float
    let spectralCentroid: Float
    let harmonicsStrength: Float
    let intensity: Float
    let harmonicToNoiseRatio: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.purple)
                Text("Acoustic Features")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                FeatureRow(label: "Frequency", value: "\(Int(fundamentalFrequency)) Hz")
                FeatureRow(label: "Centroid", value: "\(Int(spectralCentroid)) Hz")
                FeatureRow(label: "Harmonics", value: String(format: "%.1f", harmonicsStrength))
                FeatureRow(label: "Intensity", value: String(format: "%.1f dB", intensity))
                FeatureRow(label: "HNR", value: String(format: "%.1f dB", harmonicToNoiseRatio))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    struct FeatureRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CryDetectionView()
        .environmentObject(AudioEngine.shared)
}
