//
//  HomeView.swift
//  BabyInCarApp
//
//  Premium home dashboard with elegant design and animations
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var aiEngine = AIRecommendationEngine.shared
    @StateObject private var emergencyService = EmergencyCryStopService.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding

    @State private var quickPickPlaylists: [Playlist] = []
    @State private var isLoading = true
    @State private var showingEmergencyMode = false
    @State private var showingVoiceInput = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignTokens.spacingL) {
                    // Hero header with time-aware greeting
                    heroHeader

                    // Emergency Cry-Stop Button with pulsing glow
                    emergencyButton

                    // Voice Control Button
                    voiceControlButton

                    // Now Playing (if something is playing)
                    if audioEngine.currentTrack != nil {
                        nowPlayingSection
                    }

                    // Favorites Section (if user has favorites)
                    if !favoritesManager.favoriteTracks.isEmpty {
                        favoritesSection
                    }

                    // Quick Picks
                    quickPicksSection

                    // Categories
                    categoriesSection
                }
                .padding(.bottom, bottomPadding + 20)
            }
            .scrollIndicators(.visible)
            .background(
                // Subtle gradient background
                LinearGradient(
                    colors: [Color.appBackground, Color.appWarmCream.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
        .task {
            await loadQuickPicks()
        }
        .fullScreenCover(isPresented: $showingEmergencyMode) {
            EmergencyModeView()
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceControlSheet()
        }
    }

    // MARK: - Hero Header with Time-Aware Greeting
    private var heroHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(timeBasedGreeting)
                        .font(.appTitle)
                        .foregroundColor(.appText)

                    if let baby = appState.currentBaby {
                        HStack(spacing: DesignTokens.spacingS) {
                            Text(baby.displayName)
                                .font(.appBodyMedium)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appPrimary, .appSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("•")
                                .foregroundColor(.appTextTertiary)

                            Text(baby.formattedAge)
                                .font(.appBody)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }

                Spacer()

                // Animated settings button
                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        Circle()
                            .fill(Color.appCardBackground)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Time indicator pill
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: timeIcon)
                    .font(.system(size: 12))
                Text(timeOfDayText)
                    .font(.appCaption)
            }
            .foregroundColor(.appTextSecondary)
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.vertical, DesignTokens.spacingXS)
            .background(
                Capsule()
                    .fill(Color.appPrimary.opacity(0.1))
            )
            .padding(.top, DesignTokens.spacingS)
        }
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning!"
        case 12..<17: return "Good Afternoon!"
        case 17..<21: return "Good Evening!"
        default: return "Sweet Dreams!"
        }
    }

    private var timeIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private var timeOfDayText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning time"
        case 12..<17: return "Afternoon nap time"
        case 17..<21: return "Evening wind down"
        default: return "Bedtime mode"
        }
    }

    // MARK: - Emergency Button with Pulsing Glow
    private var emergencyButton: some View {
        EmergencyPulsingButton {
            if let baby = appState.currentBaby {
                emergencyService.activate(for: baby)
                showingEmergencyMode = true
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Voice Control Button
    private var voiceControlButton: some View {
        Button {
            showingVoiceInput = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)

                Text("Voice Control")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appText)

                Spacer()

                Text("Hands-free")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.1))
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4)
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Now Playing Section
    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOW PLAYING")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                // Album art / category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: audioEngine.currentTrack?.category.icon ?? "music.note")
                        .font(.system(size: 28))
                        .foregroundColor(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(audioEngine.currentTrack?.title ?? "Unknown")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    Text(audioEngine.currentTrack?.category.rawValue ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appPrimary)
                                .frame(width: geometry.size.width * CGFloat(audioEngine.currentTime / max(1, audioEngine.duration)), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Spacer()

                // Play/Pause button
                Button {
                    if audioEngine.playbackState.isPlaying {
                        audioEngine.pause()
                    } else {
                        audioEngine.resume()
                    }
                } label: {
                    Image(systemName: audioEngine.playbackState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8)
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Favorites Section
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.appSecondary)

                Text("Your Favorites")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)

                Spacer()

                NavigationLink(destination: FavoritesView()) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoritesManager.getFavoriteTracks().prefix(6)) { track in
                        FavoriteTrackCard(track: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Quick Picks Section
    private var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let baby = appState.currentBaby {
                    Text("Quick Picks for \(baby.formattedAge)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appText)
                } else {
                    Text("Quick Picks")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appText)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(quickPickPlaylists.prefix(6)) { playlist in
                        QuickPickCard(playlist: playlist) {
                            audioEngine.play(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AudioCategory.allCases) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        CategoryCard(category: category)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Load Data
    private func loadQuickPicks() async {
        isLoading = true
        if let baby = appState.currentBaby {
            quickPickPlaylists = await aiEngine.getQuickPicks(for: baby)
        }
        isLoading = false
    }
}

// MARK: - Favorite Track Card
struct FavoriteTrackCard: View {
    let track: AudioTrack
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var favoritesManager = FavoritesManager.shared

    var body: some View {
        Button {
            audioEngine.play(track: track)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.forCategory(track.category).opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: track.category.icon)
                            .font(.system(size: 32))
                            .foregroundColor(Color.forCategory(track.category))
                    }

                    // Favorite indicator
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appSecondary)
                        .padding(6)
                }

                Text(track.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 100)
        }
    }
}

// MARK: - Quick Pick Card
struct QuickPickCard: View {
    let playlist: Playlist
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.forCategory(playlist.category ?? .whiteNoise).opacity(0.15))
                        .frame(height: 80)

                    Image(systemName: playlist.category?.icon ?? "music.note.list")
                        .font(.system(size: 28))
                        .foregroundColor(Color.forCategory(playlist.category ?? .whiteNoise))
                }

                Text(playlist.category?.rawValue ?? playlist.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: AudioCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundColor(Color.forCategory(category))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.forCategory(category).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(category.description)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
    }
}

// MARK: - Emergency Mode View
struct EmergencyModeView: View {
    @StateObject private var emergencyService = EmergencyCryStopService.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.appDanger.opacity(0.9), Color.appDanger],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Phase indicator
                VStack(spacing: 16) {
                    Text(emergencyService.currentPhase.rawValue)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 150, height: 150)

                        Circle()
                            .trim(from: 0, to: emergencyService.phaseProgress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear, value: emergencyService.phaseProgress)

                        VStack {
                            Image(systemName: phaseIcon)
                                .font(.system(size: 40))
                                .foregroundColor(.white)

                            Text("\(Int(emergencyService.phaseProgress * 100))%")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Phase description
                Text(phaseDescription)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        if let baby = appState.currentBaby {
                            emergencyService.reportSuccess(for: baby)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Baby is Calm")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.appDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                    }

                    Button {
                        emergencyService.deactivate()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var phaseIcon: String {
        switch emergencyService.currentPhase {
        case .idle: return "play.circle"
        case .listening: return "ear.badge.waveform"
        case .detected: return "exclamationmark.triangle"
        case .attention: return "exclamationmark.circle"
        case .transition: return "arrow.down.circle"
        case .sustained: return "heart.circle"
        case .adapting: return "waveform.path"
        case .complete: return "checkmark.circle"
        }
    }

    private var phaseDescription: String {
        switch emergencyService.currentPhase {
        case .idle:
            return "Ready to start calming sequence"
        case .listening:
            return "Listening for baby's cry..."
        case .detected:
            return "Cry detected! Preparing response..."
        case .attention:
            return "Playing attention-grabbing sounds to interrupt crying"
        case .transition:
            return "Gradually transitioning to calming sounds"
        case .sustained:
            return "Sustained soothing for sleep transition"
        case .adapting:
            return "Adapting response to baby's needs"
        case .complete:
            return "Baby should be calm now"
        }
    }
}

// MARK: - Voice Control Sheet
struct VoiceControlSheet: View {
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var voiceHandler = VoiceCommandHandler.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    @State private var commandFeedback: String?
    @State private var showingSuccess = false
    @State private var continuousMode = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Microphone visualization with success/error state
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .fill(circleColor.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .scaleEffect(speechService.isListening ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechService.isListening)

                    // Main circle
                    Circle()
                        .fill(circleColor)
                        .frame(width: 120, height: 120)

                    Image(systemName: circleIcon)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }

                // Status text
                Text(statusText)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(circleColor)

                // Command feedback banner
                if let feedback = commandFeedback {
                    HStack(spacing: 12) {
                        Image(systemName: showingError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(circleColor)

                        Text(feedback)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(circleColor.opacity(0.15))
                    )
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                }

                // Recognized text
                if !speechService.recognizedText.isEmpty && !showingSuccess {
                    VStack(spacing: 8) {
                        Text("I heard:")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)

                        Text(speechService.recognizedText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appPrimary.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 32)
                }

                // Voice command suggestions (hide when listening or showing success)
                if !speechService.isListening && !showingSuccess {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try saying:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextSecondary)

                        VoiceCommandSuggestion(command: "\"Play\" or \"Pause\"")
                        VoiceCommandSuggestion(command: "\"Next\" or \"Previous\"")
                        VoiceCommandSuggestion(command: "\"Volume up\" or \"Louder\"")
                        VoiceCommandSuggestion(command: "\"Play lullabies\"")
                        VoiceCommandSuggestion(command: "\"Emergency mode\"")
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Continuous mode toggle
                Toggle(isOn: $continuousMode) {
                    HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.appPrimary)
                        Text("Continuous listening")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
                .padding(.horizontal, 32)

                // Listen button
                Button {
                    if speechService.isListening {
                        speechService.stopListening()
                    } else {
                        startListening()
                    }
                } label: {
                    HStack {
                        Image(systemName: speechService.isListening ? "stop.fill" : "mic.fill")
                        Text(speechService.isListening ? "Stop Listening" : "Start Listening")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(speechService.isListening ? Color.appDanger : Color.appPrimary)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Voice Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        speechService.stopListening()
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .voiceCommandExecuted)) { notification in
                handleCommandExecuted(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .voiceCommandNotRecognized)) { notification in
                handleCommandNotRecognized(notification)
            }
            .onAppear {
                // Auto-start listening when sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startListening()
                }
            }
        }
    }

    private var statusText: String {
        if showingSuccess {
            return "Done!"
        } else if showingError {
            return "Try again"
        } else if speechService.isListening {
            return "Listening..."
        } else {
            return "Tap to speak"
        }
    }

    private var circleColor: Color {
        if showingSuccess {
            return .green
        } else if showingError {
            return .orange
        } else {
            return .appPrimary
        }
    }

    private var circleIcon: String {
        if showingSuccess {
            return "checkmark"
        } else if showingError {
            return "xmark"
        } else {
            return "mic.fill"
        }
    }

    @State private var showingError = false

    private func startListening() {
        showingSuccess = false
        showingError = false
        commandFeedback = nil
        speechService.startListening()
    }

    private func handleCommandExecuted(_ notification: Notification) {
        guard let message = notification.userInfo?["message"] as? String,
              let success = notification.userInfo?["success"] as? Bool,
              success else { return }

        // Show success feedback
        withAnimation(.spring(response: 0.3)) {
            showingSuccess = true
            showingError = false
            commandFeedback = message
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Handle next action based on mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if continuousMode {
                // Restart listening for next command
                withAnimation {
                    showingSuccess = false
                    commandFeedback = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startListening()
                }
            } else {
                // Auto-dismiss after successful command
                dismiss()
            }
        }
    }

    private func handleCommandNotRecognized(_ notification: Notification) {
        // Show error feedback
        withAnimation(.spring(response: 0.3)) {
            showingError = true
            showingSuccess = false
            commandFeedback = "Command not recognized"
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Restart listening after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showingError = false
                commandFeedback = nil
            }
            if continuousMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startListening()
                }
            }
        }
    }
}

struct VoiceCommandSuggestion: View {
    let command: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.appPrimary.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(command)
                .font(.system(size: 14))
                .foregroundColor(.appText)
        }
    }
}

// MARK: - Emergency Pulsing Button
struct EmergencyPulsingButton: View {
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                // Outer glow pulse
                RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                    .fill(Color.appDanger.opacity(glowOpacity))
                    .scaleEffect(pulseScale)
                    .blur(radius: 8)

                // Main button
                HStack(spacing: DesignTokens.spacingM) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("EMERGENCY CRY-STOP")
                            .font(.appBodyMedium)
                            .foregroundColor(.white)

                        Text("Tap for instant calming")
                            .font(.appCaption)
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(DesignTokens.spacingM)
                .background(
                    LinearGradient(
                        colors: [Color.appDanger, Color.appDanger.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusL))
                .shadow(color: Color.appDanger.opacity(0.4), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(EmergencyButtonPressStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.03
                glowOpacity = 0.5
            }
        }
    }
}

struct EmergencyButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Premium Section Header
struct PremiumSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .appPrimary
    var showSeeAll: Bool = false
    var seeAllAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: DesignTokens.spacingS) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundColor(.appText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }

            Spacer()

            if showSeeAll, let action = seeAllAction {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.appSubheadline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Premium Quick Pick Card
struct PremiumQuickPickCard: View {
    let playlist: Playlist
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: DesignTokens.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.forCategory(playlist.category ?? .whiteNoise).opacity(0.2),
                                    Color.forCategory(playlist.category ?? .whiteNoise).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)

                    // Category icon
                    Image(systemName: playlist.category?.icon ?? "music.note.list")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color.forCategory(playlist.category ?? .whiteNoise))

                    // Play indicator on hover
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.3 : 0))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.forCategory(playlist.category ?? .whiteNoise))
                                .opacity(isPressed ? 1 : 0)
                        )
                }

                Text(playlist.category?.rawValue ?? playlist.name)
                    .font(.appCaption)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(CardPressStyle())
    }
}

// CardPressStyle moved to ButtonStyles.swift to avoid redeclaration

// MARK: - Premium Category Card
struct PremiumCategoryCard: View {
    let category: AudioCategory

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Category icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.forCategory(category).opacity(0.2),
                                Color.forCategory(category).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.forCategory(category))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.appBodyMedium)
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(category.description)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextTertiary)
        }
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
}
