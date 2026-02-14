//
//  BabyInCarApp.swift
//  Lulla
//
//  Lulla - Calm Baby, Anywhere
//  AI-powered baby calming for car, home, and everywhere
//

import SwiftUI
import UserNotifications
import Intents
import WatchConnectivity

// MARK: - App Delegate for Siri Integration + Lifecycle Management
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // NOTE: Siri authorization is NOT requested on launch to avoid threading issues.
        // iOS automatically prompts for Siri authorization when the user first invokes
        // a Siri intent for this app (e.g., "Hey Siri, play lullabies in Lulla").
        // Requesting it proactively can cause crashes due to MainActor isolation.
        return true
    }

    /// Handle Siri intents when app is launched via Siri
    /// NOTE: Pause/Resume/Skip are handled by MPRemoteCommandCenter, not intents
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // Route supported media intents to SiriIntentHandler
        switch intent {
        case is INPlayMediaIntent:
            return SiriIntentHandler.shared
        case is INSearchForMediaIntent:
            return SiriIntentHandler.shared
        case is INAddMediaIntent:
            return SiriIntentHandler.shared
        default:
            return nil
        }
    }

    /// CRITICAL: Clean up audio resources when app is terminated (force quit)
    /// This ensures microphone is released when user kills the app
    func applicationWillTerminate(_ application: UIApplication) {
        print("[AppDelegate] 🛑 App terminating - cleaning up audio resources")
        cleanupAudioResources()
    }

    /// Clean up all audio resources to release audio session
    private func cleanupAudioResources() {
        DispatchQueue.main.async {
            // Stop audio playback
            AudioEngine.shared.stop()
            print("[AppDelegate] ✅ AudioEngine stopped")

            // Force deactivate audio session to release all audio hardware
            AudioSessionManager.shared.forceDeactivate()
            print("[AppDelegate] ✅ AudioSession deactivated")
        }
    }
}

@main
struct BabyInCarApp: App {
    // Connect AppDelegate for Siri support
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()
    @StateObject private var audioEngine = AudioEngine.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSplash = true

    /// Track scene phase for app lifecycle management
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Configure app appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(audioEngine)
                    .environmentObject(subscriptionManager)
                    .onAppear {
                        setupApp()
                    }
                    // SIRI INTENT HANDLING
                    // Handle user activities from Intents Extension
                    .onContinueUserActivity("com.lulla.playMedia") { userActivity in
                        handlePlayMediaActivity(userActivity)
                    }
                    .onContinueUserActivity("com.lulla.searchMedia") { userActivity in
                        handleSearchMediaActivity(userActivity)
                    }
                    .onContinueUserActivity("com.lulla.addToFavorites") { userActivity in
                        handleAddToFavoritesActivity(userActivity)
                    }
                    // NOTE: Pause/Resume/Skip are handled by MPRemoteCommandCenter
                    // in NowPlayingService.swift - no user activity needed

                // Animated splash screen overlay
                if showSplash {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        // CRITICAL: Handle app lifecycle changes to properly release microphone
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(to: newPhase)
        }
    }

    /// Handle scene phase changes for proper audio resource management
    private func handleScenePhaseChange(to newPhase: ScenePhase) {
        print("[BabyInCarApp] 📱 Scene phase changed → \(newPhase)")

        switch newPhase {
        case .background:
            print("[BabyInCarApp] 🌙 App entering background")
            // Note: We do NOT stop AudioEngine playback - background audio is a feature
            // Users may want lullabies to continue playing when app is backgrounded

        case .inactive:
            print("[BabyInCarApp] ⏸️ App inactive")

        case .active:
            print("[BabyInCarApp] ✅ App active")
            // Restore audio session for playback if needed
            if audioEngine.playbackState.isPlaying || audioEngine.currentTrack != nil {
                audioEngine.configureAudioSession()
                print("[BabyInCarApp] 🔊 Audio session restored for playback")
            }

        @unknown default:
            break
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.appText)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.appText)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.appBackground)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func setupApp() {
        // MEMORY SAFETY: Start memory monitoring early
        setupMemoryMonitoring()

        // CRITICAL: Load user data FIRST before checking conditions
        appState.loadUserData()

        // Initialize Watch connectivity
        _ = WatchSyncManager.shared
        print("[BabyInCarApp] ✅ WatchSyncManager initialized for Watch connectivity")

        // Request necessary permissions and setup audio services
        Task {
            _ = await NotificationService.shared.requestAuthorization()

            // Initialize audio session for playback
            audioEngine.configureAudioSession()

            // Initialize default playlist so player is always visible (but NOT auto-playing)
            // Playback only starts on manual user action
            await initializeDefaultPlaylist()
        }
    }

    /// Initialize a default classical playlist so the player is always visible and ready
    /// Player shows the track but stays SILENT until user taps Play
    private func initializeDefaultPlaylist() async {
        // Wait a brief moment for ContentLibraryService to load
        try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

        // Get classical music tracks for default queue (high calming scores first)
        let library = ContentLibraryService.shared
        let classicalTracks = library.allTracks
            .filter { $0.category == .classicalMusic }
            .sorted { $0.calmingScore > $1.calmingScore }

        // Use top 20 classical tracks or fallback to emergency track
        let selectedTracks = Array(classicalTracks.prefix(20))

        guard !selectedTracks.isEmpty else {
            // Fallback: use generated emergency track if no classical tracks
            await MainActor.run {
                audioEngine.currentTrack = AudioTrack.defaultEmergencyTrack()
            }
            return
        }

        await MainActor.run {
            // Set first track as current (for player display) but DON'T play
            let defaultTrack = selectedTracks.first!
            audioEngine.currentTrack = defaultTrack

            // Queue remaining tracks for up-next
            audioEngine.upNextQueue = Array(selectedTracks.dropFirst())

            // Ensure playback is stopped - player visible but silent
            // Playback starts ONLY on manual Play tap
            if audioEngine.playbackState.isPlaying {
                audioEngine.pause()
            }

            print("[BabyInCarApp] 🎵 Default playlist initialized with \(selectedTracks.count) classical tracks")
            print("[BabyInCarApp] 🎵 First track: \(defaultTrack.title) - player visible, waiting for user action")
        }
    }

    /// Setup memory pressure monitoring to prevent iOS from killing the app
    /// MEMORY FIX (0030): Consolidated into single MemoryMonitor (was duplicated with MemoryPressureMonitor)
    private func setupMemoryMonitoring() {
        let memoryMonitor = MemoryMonitor.shared

        memoryMonitor.onWarningLevel = {
            print("[MemoryMonitor] ⚠️ Warning level - reducing features")
        }

        memoryMonitor.onCriticalLevel = {
            print("[MemoryMonitor] 🔴 Critical level - aggressive cleanup")
            Task { @MainActor in
                if !AudioEngine.shared.playbackState.isPlaying {
                    Task { await AudioCacheService.shared.clearAllCache() }
                } else {
                    print("[MemoryMonitor] ⏭️ Skipping cache clear - audio is playing")
                }
            }
        }

        memoryMonitor.onEmergencyLevel = {
            print("[MemoryMonitor] 🚨 Emergency level")
            Task { @MainActor in
                if !AudioEngine.shared.playbackState.isPlaying {
                    Task { await AudioCacheService.shared.clearAllCache() }
                    print("[MemoryMonitor] Cache cleared to prevent crash")
                } else {
                    print("[MemoryMonitor] ✅ Audio protected - playback continues")
                }
            }
        }

        // Single 15s monitoring interval (was 2s with MemoryPressureMonitor - too aggressive)
        memoryMonitor.startMonitoring()
    }

    // MARK: - Siri Intent Handlers

    /// Handle play media activity from Intents Extension
    private func handlePlayMediaActivity(_ userActivity: NSUserActivity) {
        guard let userInfo = userActivity.userInfo,
              let action = userInfo["action"] as? String else {
            print("🎤 [App] Invalid play media activity")
            return
        }

        print("🎤 [App] Received play media activity")

        switch action {
        case "emergency":
            // Play calming content for baby
            Task { @MainActor in
                // Play default calming content
                playDefault()
                print("🎤 [App] Playing calming content")
            }

        case "playCategory":
            guard let categoryString = userInfo["category"] as? String else { return }
            playCategory(categoryString)

        case "search":
            guard let searchText = userInfo["searchText"] as? String else { return }
            playSearch(searchText)

        default:
            print("🎤 [App] Unknown action: \(action)")
        }
    }

    /// Handle search media activity from Intents Extension
    private func handleSearchMediaActivity(_ userActivity: NSUserActivity) {
        guard let userInfo = userActivity.userInfo,
              let searchTerm = userInfo["searchTerm"] as? String else {
            print("🎤 [App] Invalid search media activity")
            return
        }

        print("🎤 [App] Processing search request")
        playSearch(searchTerm)
    }

    /// Handle add to favorites activity from Intents Extension
    private func handleAddToFavoritesActivity(_ userActivity: NSUserActivity) {
        guard let userInfo = userActivity.userInfo,
              let trackIdString = userInfo["trackId"] as? String else {
            print("🎤 [App] Invalid add to favorites activity")
            return
        }

        print("🎤 [App] Processing add to favorites")

        Task { @MainActor in
            // If "current", use currently playing track
            if trackIdString == "current" {
                if let currentTrack = audioEngine.currentTrack {
                    if !FavoritesManager.shared.isFavorite(track: currentTrack) {
                        FavoritesManager.shared.toggleFavorite(track: currentTrack)
                    }
                    print("🎤 [App] Added current track to favorites")
                }
            } else if let trackId = UUID(uuidString: trackIdString) {
                // Find specific track by ID
                let track = ContentLibraryService.shared.allTracks.first { $0.id == trackId }
                if let track = track {
                    if !FavoritesManager.shared.isFavorite(track: track) {
                        FavoritesManager.shared.toggleFavorite(track: track)
                    }
                    print("🎤 [App] Added track to favorites")
                }
            }
        }
    }

    // NOTE: Pause/Resume/Skip are handled by MPRemoteCommandCenter in NowPlayingService.swift
    // iOS routes "Hey Siri, pause/resume/next/previous" to the Now Playing controls automatically.

    /// Play a specific category
    private func playCategory(_ categoryString: String) {
        // Map category identifier to AudioCategory
        let category: AudioCategory?
        switch categoryString {
        case "lullabies": category = .lullabies
        case "classicalMusic": category = .classicalMusic
        case "fairyTales": category = .fairyTales
        case "natureSounds": category = .natureSounds
        case "ambient": category = .ambient
        case "instrumental": category = .instrumental
        case "childrenSongs": category = .childrenSongs
        default: category = nil
        }

        guard let category = category else {
            print("🎤 [App] Unknown category")
            playDefault()
            return
        }

        print("🎤 [App] Playing category")

        let tracks = ContentLibraryService.shared.getTracks(for: category)
        guard !tracks.isEmpty else {
            print("🎤 [App] No tracks available for category")
            playDefault()
            return
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Siri: \(category.rawValue)",
            tracks: Array(tracks.shuffled().prefix(20)),
            createdAt: Date()
        )

        audioEngine.play(playlist: playlist)

        // Donate shortcut for this category
        SiriShortcutsService.shared.donatePlaybackShortcut(for: category)
    }

    /// Search and play matching tracks
    private func playSearch(_ searchTerm: String) {
        print("🎤 [App] Processing search request")

        let matches = ContentLibraryService.shared.allTracks.filter { track in
            track.title.lowercased().contains(searchTerm.lowercased()) ||
            track.artist.lowercased().contains(searchTerm.lowercased())
        }

        if !matches.isEmpty {
            let playlist = Playlist(
                id: UUID(),
                name: "Siri: \(searchTerm)",
                tracks: Array(matches.prefix(20)),
                createdAt: Date()
            )
            audioEngine.play(playlist: playlist)
        } else {
            print("🎤 [App] No matches found")
            playDefault()
        }
    }

    /// Play default content as fallback
    private func playDefault() {
        print("🎤 [App] Playing default content")

        let tracks = ContentLibraryService.shared.allTracks
            .sorted { $0.calmingScore > $1.calmingScore }

        guard !tracks.isEmpty else {
            audioEngine.play(track: AudioTrack.defaultEmergencyTrack())
            return
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Siri: Lulla Music",
            tracks: Array(tracks.prefix(20)),
            createdAt: Date()
        )
        audioEngine.play(playlist: playlist)
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool = false
    @Published var currentBaby: Baby?
    @Published var selectedLanguages: [Language] = [.english]
    @Published var isPremiumUser: Bool = false
    @Published var offlineMode: Bool = false

    /// Smooth audio transitions with crossfade (DEFAULT: TRUE)
    /// When enabled, track switches fade out current track and fade in new track
    @Published var smoothTransitionsEnabled: Bool = true

    private let userDefaults = UserDefaults.standard

    init() {
        loadUserData()
    }

    func loadUserData() {
        isOnboardingComplete = userDefaults.bool(forKey: "isOnboardingComplete")
        isPremiumUser = userDefaults.bool(forKey: "isPremiumUser")

        // Smooth transitions defaults to TRUE if not set
        if userDefaults.object(forKey: "smoothTransitionsEnabled") == nil {
            smoothTransitionsEnabled = true  // Default ON for smooth UX
        } else {
            smoothTransitionsEnabled = userDefaults.bool(forKey: "smoothTransitionsEnabled")
        }

        if let babyData = userDefaults.data(forKey: "currentBaby"),
           let baby = try? JSONDecoder().decode(Baby.self, from: babyData) {
            currentBaby = baby
        }

        if let languageData = userDefaults.data(forKey: "selectedLanguages"),
           let languages = try? JSONDecoder().decode([Language].self, from: languageData) {
            selectedLanguages = languages
        }
    }

    func saveUserData() {
        userDefaults.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        userDefaults.set(isPremiumUser, forKey: "isPremiumUser")
        userDefaults.set(smoothTransitionsEnabled, forKey: "smoothTransitionsEnabled")

        if let baby = currentBaby,
           let babyData = try? JSONEncoder().encode(baby) {
            userDefaults.set(babyData, forKey: "currentBaby")
        }

        if let languageData = try? JSONEncoder().encode(selectedLanguages) {
            userDefaults.set(languageData, forKey: "selectedLanguages")
        }
    }

    /// Toggle smooth audio transitions and save preference
    func setSmoothTransitions(_ enabled: Bool) {
        smoothTransitionsEnabled = enabled
        saveUserData()
        // Sync with AudioEngine
        AudioEngine.shared.smoothTransitionsEnabled = enabled
    }

    func completeOnboarding(baby: Baby, languages: [Language]) {
        currentBaby = baby
        selectedLanguages = languages
        isOnboardingComplete = true
        saveUserData()
    }

    /// Complete onboarding with a single UI language (language is automatically set via LanguageManager)
    func completeOnboarding(baby: Baby, language: SupportedLanguage) {
        currentBaby = baby
        // Map SupportedLanguage to content Language for filtering
        selectedLanguages = [language.toContentLanguage]
        isOnboardingComplete = true
        saveUserData()
    }

    func updateBaby(_ baby: Baby) {
        currentBaby = baby
        saveUserData()
    }
}

// MARK: - Notification Service
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized: Bool = false

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization failed: \(error)")
            isAuthorized = false
            return false
        }
    }

    func scheduleSleepTimerNotification(afterSeconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Sleep Timer"
        content.body = "Audio will stop soon"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, afterSeconds - 60), repeats: false)
        let request = UNNotificationRequest(identifier: "sleepTimer", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
