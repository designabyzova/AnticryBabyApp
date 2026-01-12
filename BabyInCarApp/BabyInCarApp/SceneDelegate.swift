//
//  SceneDelegate.swift
//  BabyInCarApp
//
//  Main app scene delegate with Siri Shortcuts support
//

#if canImport(UIKit)
import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Create the SwiftUI view
        let contentView = ContentView()
            .environmentObject(AppState())
            .environmentObject(AudioEngine.shared)
            .environmentObject(SubscriptionManager.shared)
            .environmentObject(ContentLibraryService.shared)
            .environmentObject(AIRecommendationEngine.shared)
            .environmentObject(FavoritesManager.shared)

        // Create UIWindow
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()

        // Handle any user activities from Siri Shortcuts (cold launch)
        for userActivity in connectionOptions.userActivities {
            handleUserActivity(userActivity)
        }

        // Donate common shortcuts to Siri
        Task { @MainActor in
            SiriShortcutsService.shared.donateAllShortcuts()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is released by the system
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restart any tasks paused when scene was inactive
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when scene moves from active to inactive
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from background to foreground
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save any data and release shared resources
    }

    // MARK: - Siri Shortcuts / NSUserActivity Handling

    /// Handle NSUserActivity when app is continued via Siri Shortcuts (warm launch)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity)
    }

    /// Process a user activity (from Siri Shortcut or Handoff)
    private func handleUserActivity(_ userActivity: NSUserActivity) {
        let activityType = userActivity.activityType
        let userInfo = userActivity.userInfo

        print("[SceneDelegate] Handling user activity: \(activityType)")

        // Delegate to SiriShortcutsService
        Task { @MainActor in
            SiriShortcutsService.shared.handleShortcut(
                activityType: activityType,
                userInfo: userInfo
            )
        }
    }
}
#endif
