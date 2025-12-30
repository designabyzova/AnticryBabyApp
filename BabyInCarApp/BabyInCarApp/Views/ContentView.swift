//
//  ContentView.swift
//  BabyInCarApp
//
//  Main content view with navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var voiceHandler = VoiceCommandHandler.shared

    var body: some View {
        Group {
            if appState.isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            voiceHandler.configure(with: appState)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var selectedTab = 0

    // Calculate bottom padding based on what's visible
    private var bottomPadding: CGFloat {
        let tabBarHeight: CGFloat = 85
        let miniPlayerHeight: CGFloat = audioEngine.currentTrack != nil ? 74 : 0
        return tabBarHeight + miniPlayerHeight
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content - each view handles its own scrolling
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    LibraryView()
                case 2:
                    FavoritesView()
                case 3:
                    ProfileView()
                default:
                    HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom overlay stack (mini player + tab bar)
            VStack(spacing: 0) {
                // Mini Player
                if audioEngine.currentTrack != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: audioEngine.currentTrack != nil)
                }

                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Configure audio session on app launch
            audioEngine.configureAudioSession()
        }
        // Pass bottom padding to child views via environment
        .environment(\.bottomSafeAreaPadding, bottomPadding)
    }
}

// Environment key for bottom padding
private struct BottomSafeAreaPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 120
}

extension EnvironmentValues {
    var bottomSafeAreaPadding: CGFloat {
        get { self[BottomSafeAreaPaddingKey.self] }
        set { self[BottomSafeAreaPaddingKey.self] = newValue }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("books.vertical.fill", "Library"),
        ("heart.fill", "Favorites"),
        ("person.fill", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Color.appCardBackground
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Mini Player View
struct MiniPlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var showingFullPlayer = false

    var body: some View {
        Button {
            showingFullPlayer = true
        } label: {
            HStack(spacing: 12) {
                // Album Art / Category Icon
                ZStack {
                    Circle()
                        .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.2))

                    Image(systemName: audioEngine.currentTrack?.category.icon ?? "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))
                }
                .frame(width: 44, height: 44)

                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioEngine.currentTrack?.title ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    Text(audioEngine.currentTrack?.artist ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Playback Controls
                HStack(spacing: 16) {
                    Button {
                        if audioEngine.playbackState.isPlaying {
                            audioEngine.pause()
                        } else {
                            audioEngine.resume()
                        }
                    } label: {
                        Image(systemName: audioEngine.playbackState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appPrimary)
                    }

                    Button {
                        audioEngine.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showingFullPlayer) {
            PlayerView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
        .environmentObject(SubscriptionManager.shared)
}
