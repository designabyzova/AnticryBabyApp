//
//  BabyInCarApp.swift
//  BabyInCarApp
//
//  Baby in Car Without Tears - AI-powered calming audio for babies
//

import SwiftUI
import UserNotifications

@main
struct BabyInCarApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var audioEngine = AudioEngine.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        // Configure app appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(subscriptionManager)
                .onAppear {
                    setupApp()
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
        // Request necessary permissions
        Task {
            await SpeechRecognitionService.shared.requestAuthorization()
            _ = await NotificationService.shared.requestAuthorization()
        }

        // Load cached data
        appState.loadUserData()

        // Initialize audio session
        audioEngine.configureAudioSession()
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

    private let userDefaults = UserDefaults.standard

    init() {
        loadUserData()
    }

    func loadUserData() {
        isOnboardingComplete = userDefaults.bool(forKey: "isOnboardingComplete")
        isPremiumUser = userDefaults.bool(forKey: "isPremiumUser")

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

        if let baby = currentBaby,
           let babyData = try? JSONEncoder().encode(baby) {
            userDefaults.set(babyData, forKey: "currentBaby")
        }

        if let languageData = try? JSONEncoder().encode(selectedLanguages) {
            userDefaults.set(languageData, forKey: "selectedLanguages")
        }
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
