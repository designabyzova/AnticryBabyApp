import SwiftUI
import WatchKit
import UserNotifications

@main
struct BabyInCarWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var audioPlayer = WatchAudioPlayer.shared

    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[WatchApp] Notification permission error: \(error)")
            } else {
                print("[WatchApp] Notification permission granted: \(granted)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
                .environmentObject(audioPlayer)
        }
    }
}

