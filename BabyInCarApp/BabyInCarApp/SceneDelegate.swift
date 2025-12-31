//
//  SceneDelegate.swift
//  BabyInCarApp
//
//  Main app scene delegate
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
            .environmentObject(EmergencyCryStopService.shared)
            .environmentObject(SpeechRecognitionService.shared)
            .environmentObject(FavoritesManager.shared)

        // Create UIWindow
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
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
}
#endif
