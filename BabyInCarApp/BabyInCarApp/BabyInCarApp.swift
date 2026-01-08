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

// MARK: - App Delegate for Siri Integration
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // NOTE: Siri authorization is NOT requested on launch to avoid threading issues.
        // iOS automatically prompts for Siri authorization when the user first invokes
        // a Siri intent for this app (e.g., "Hey Siri, play lullabies in Lulla").
        // Requesting it proactively can cause crashes due to MainActor isolation.
        return true
    }

    /// Handle Siri intents when app is launched via Siri
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // Route all supported media intents to SiriIntentHandler
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
}

@main
struct BabyInCarApp: App {
    // Connect AppDelegate for Siri support
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()
    @StateObject private var audioEngine = AudioEngine.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSplash = true

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
        // This ensures isOnboardingComplete and currentBaby are loaded from UserDefaults
        appState.loadUserData()

        // 🔧 FIX: Configure VoiceCommandHandler with AppState
        // This was missing - voice commands weren't executing because handler had no state!
        VoiceCommandHandler.shared.configure(with: appState)
        print("[BabyInCarApp] ✅ VoiceCommandHandler configured with AppState")

        // Request necessary permissions and setup audio services
        // CRITICAL: All audio session operations are sequenced to prevent conflicts
        Task {
            await SpeechRecognitionService.shared.requestAuthorization()
            _ = await NotificationService.shared.requestAuthorization()

            // AUTO-ENABLE CRY MONITORING (Default: ON for parent safety)
            // Now data is loaded, so conditions will check actual saved values
            // Condition 1: User hasn't disabled auto-monitoring in settings
            // Condition 2: Onboarding is complete (baby is configured)
            // Condition 3: We have a baby profile
            print("[BabyInCarApp] 🔍 Checking cry monitoring conditions:")
            print("[BabyInCarApp]   - autoCryMonitoringEnabled: \(appState.autoCryMonitoringEnabled)")
            print("[BabyInCarApp]   - isOnboardingComplete: \(appState.isOnboardingComplete)")
            print("[BabyInCarApp]   - currentBaby: \(appState.currentBaby?.name ?? "nil")")

            if appState.autoCryMonitoringEnabled &&
               appState.isOnboardingComplete &&
               appState.currentBaby != nil {
                do {
                    print("[BabyInCarApp] 🔊 Auto-enabling cry monitoring (default ON)")
                    try await EmergencyCryStopService.shared.enableAIMonitoring(for: appState.currentBaby!)
                } catch {
                    print("[BabyInCarApp] ⚠️ Failed to auto-enable cry monitoring: \(error)")
                }
            } else {
                print("[BabyInCarApp] ⚠️ Cry monitoring NOT auto-enabled - conditions not met")
            }

            // Initialize audio session AFTER cry monitoring setup completes
            // This prevents race conditions between CryDetection and AudioEngine
            // AudioSessionManager now coordinates all session requests by priority
            audioEngine.configureAudioSession()

            // Initialize default playlist so player is always visible (but NOT auto-playing)
            // Playback only starts on cry detection or manual user action
            await initializeDefaultPlaylist()
        }
    }

    /// Initialize a default classical playlist so the player is always visible and ready
    /// Player shows the track but stays SILENT until cry detection or user taps Play
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
            // Playback starts ONLY on cry detection or manual Play tap
            if audioEngine.playbackState.isPlaying {
                audioEngine.pause()
            }

            print("[BabyInCarApp] 🎵 Default playlist initialized with \(selectedTracks.count) classical tracks")
            print("[BabyInCarApp] 🎵 First track: \(defaultTrack.title) - player visible, waiting for cry detection or user action")
        }
    }

    /// Setup memory pressure monitoring to prevent iOS from killing the app
    private func setupMemoryMonitoring() {
        let memoryMonitor = MemoryPressureMonitor.shared

        // Warning level: reduce non-essential features
        memoryMonitor.onWarningLevel = {
            print("[MemoryMonitor] ⚠️ Warning level - reducing features")
            // Disable ML enhancement to reduce memory
            Task { @MainActor in
                CryDetectionService.shared.useMLEnhancement = false
            }
        }

        // Critical level: aggressive cleanup
        memoryMonitor.onCriticalLevel = {
            print("[MemoryMonitor] 🔴 Critical level - aggressive cleanup")
            Task { @MainActor in
                // Disable all heavy ML features
                CryDetectionService.shared.useMLEnhancement = false
                CryDetectionService.shared.useDeepInfant = false

                // Clear audio caches
                Task { await AudioCacheService.shared.clearAllCache() }
            }
        }

        // Emergency level: stop non-essential services
        memoryMonitor.onEmergencyLevel = {
            print("[MemoryMonitor] 🚨 Emergency level - stopping services")
            Task { @MainActor in
                // Stop cry detection temporarily
                CryDetectionService.shared.stopMonitoring()

                // Stop smart response engine
                SmartCryResponseEngine.shared.deactivate()

                // Clear all caches
                Task { await AudioCacheService.shared.clearAllCache() }

                print("[MemoryMonitor] Services stopped to prevent crash")
            }
        }

        // Start monitoring (check every 2 seconds for faster response)
        // CRITICAL: Must catch memory issues BEFORE iOS decides to kill
        memoryMonitor.startMonitoring(interval: 2.0)
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

    /// Auto-enable cry monitoring when app launches (DEFAULT: TRUE for safety)
    /// Users can disable this in settings if they prefer manual activation
    @Published var autoCryMonitoringEnabled: Bool = true

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

        // Auto cry monitoring defaults to TRUE if not set (opt-out, not opt-in)
        // This ensures parents have protection by default
        if userDefaults.object(forKey: "autoCryMonitoringEnabled") == nil {
            autoCryMonitoringEnabled = true  // Default ON for new users
        } else {
            autoCryMonitoringEnabled = userDefaults.bool(forKey: "autoCryMonitoringEnabled")
        }

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
        userDefaults.set(autoCryMonitoringEnabled, forKey: "autoCryMonitoringEnabled")
        userDefaults.set(smoothTransitionsEnabled, forKey: "smoothTransitionsEnabled")

        if let baby = currentBaby,
           let babyData = try? JSONEncoder().encode(baby) {
            userDefaults.set(babyData, forKey: "currentBaby")
        }

        if let languageData = try? JSONEncoder().encode(selectedLanguages) {
            userDefaults.set(languageData, forKey: "selectedLanguages")
        }
    }

    /// Toggle auto cry monitoring and save preference
    func setAutoCryMonitoring(_ enabled: Bool) {
        autoCryMonitoringEnabled = enabled
        saveUserData()
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
