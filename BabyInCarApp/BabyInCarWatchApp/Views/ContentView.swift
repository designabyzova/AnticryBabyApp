import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    @State private var selectedTab = 0
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenWatchOnboarding")

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                // Tab 1: Now Playing / Remote Control
                NowPlayingView()
                    .tag(0)

                // Tab 2: Library (Categories)
                LibraryView()
                    .tag(1)

                // Tab 3: Emergency Mode
                EmergencyView()
                    .tag(2)

                // Tab 4: Favorites
                FavoritesListView()
                    .tag(3)

                // Tab 5: Cry Alerts
                CryAlertsView()
                    .tag(4)

                // Tab 6: Settings (Sleep Timer)
                SleepTimerView()
                    .tag(5)
            }
            .tabViewStyle(.page)

            // iPhone connection status banner (only shown when disconnected)
            if !connectivityManager.isCompanionAppInstalled {
                companionNotInstalledBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if !connectivityManager.isPhoneReachable {
                iPhoneConnectionBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // Request initial sync
            connectivityManager.requestStateSync()
            connectivityManager.requestLibrarySync()
        }
        .animation(.easeInOut, value: connectivityManager.isPhoneReachable)
        .animation(.easeInOut, value: connectivityManager.isCompanionAppInstalled)
        .sheet(isPresented: $showOnboarding) {
            WatchOnboardingView(isPresented: $showOnboarding)
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "hasSeenWatchOnboarding")
                }
        }
    }

    // MARK: - Connection Banner

    private var iPhoneConnectionBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone.slash")
                .font(.caption2)
            Text("iPhone needed for cry detection")
                .font(.system(size: 10))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange)
        .cornerRadius(12)
        .padding(.top, 2)
    }

    private var companionNotInstalledBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("Open Lulla on iPhone")
                .font(.system(size: 10))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red)
        .cornerRadius(12)
        .padding(.top, 2)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(WatchAudioPlayer.shared)
}
