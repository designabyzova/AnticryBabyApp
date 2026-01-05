//
//  BabyInCarApp.swift
//  Lulla
//
//  Lulla - Calm Baby, Anywhere
//  AI-powered baby calming for car, home, and everywhere
//

import SwiftUI
import UserNotifications

@main
struct BabyInCarApp: App {
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

        // 🔧 FIX: Configure VoiceCommandHandler with AppState
        // This was missing - voice commands weren't executing because handler had no state!
        VoiceCommandHandler.shared.configure(with: appState)
        print("[BabyInCarApp] ✅ VoiceCommandHandler configured with AppState")

        // Request necessary permissions
        Task {
            await SpeechRecognitionService.shared.requestAuthorization()
            _ = await NotificationService.shared.requestAuthorization()

            // AUTO-ENABLE CRY MONITORING (Default: ON for parent safety)
            // Only auto-start if:
            // 1. User hasn't disabled auto-monitoring in settings
            // 2. Onboarding is complete (baby is configured)
            // 3. We have a baby profile
            if appState.autoCryMonitoringEnabled &&
               appState.isOnboardingComplete &&
               appState.currentBaby != nil {
                do {
                    print("[BabyInCarApp] 🔊 Auto-enabling cry monitoring (default ON)")
                    try await EmergencyCryStopService.shared.enableAIMonitoring(for: appState.currentBaby!)
                } catch {
                    print("[BabyInCarApp] ⚠️ Failed to auto-enable cry monitoring: \(error)")
                }
            }
        }

        // Load cached data
        appState.loadUserData()

        // Initialize audio session
        audioEngine.configureAudioSession()
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
