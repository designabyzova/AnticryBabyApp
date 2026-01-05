import SwiftUI
import WatchKit
import UserNotifications

@main
struct BabyInCarWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var audioPlayer = WatchAudioPlayer.shared

    init() {
        // Request notification permissions for cry alerts
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

        // Handle cry alert notifications
        WKNotificationScene(controller: CryAlertNotificationController.self, category: "CRY_ALERT")
    }
}

// MARK: - Notification Controller for Cry Alerts

class CryAlertNotificationController: WKUserNotificationHostingController<CryAlertNotificationView> {

    var alert: CryAlert?

    override var body: CryAlertNotificationView {
        CryAlertNotificationView(alert: alert)
    }

    override func didReceive(_ notification: UNNotification) {
        if let data = notification.request.content.userInfo["alertData"] as? Data {
            alert = try? JSONDecoder().decode(CryAlert.self, from: data)
        }
    }
}

struct CryAlertNotificationView: View {
    let alert: CryAlert?

    var body: some View {
        VStack(spacing: 8) {
            if let alert = alert {
                Image(systemName: alert.cryType.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(.red)

                Text(alert.cryType.displayName)
                    .font(.headline)

                Text(alert.suggestedAction)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("Cry Detected")
                    .font(.headline)
            }
        }
        .padding()
    }
}
