import SwiftUI
import WatchKit

/// Emergency mode trigger for Apple Watch
/// Starts AI-powered cry response on iPhone OR standalone mode on Watch
struct EmergencyView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    @State private var isPulsing = false
    @State private var isStandaloneEmergencyActive = false

    /// Whether any emergency mode is active (iPhone or Watch standalone)
    private var isAnyEmergencyActive: Bool {
        connectivityManager.isEmergencyModeActive || isStandaloneEmergencyActive
    }

    var body: some View {
        VStack(spacing: 16) {
            if isAnyEmergencyActive {
                activeEmergencyView
            } else {
                readyStateView
            }
        }
        .padding()
        .onAppear {
            isPulsing = true
        }
        .onChange(of: audioPlayer.isPlaying) { _, playing in
            // Track standalone emergency state
            if !playing && isStandaloneEmergencyActive && audioPlayer.isStandaloneMode {
                isStandaloneEmergencyActive = false
            }
        }
    }

    // MARK: - Ready State (Not Active)

    private var readyStateView: some View {
        VStack(spacing: 16) {
            // Status indicator showing mode
            if connectivityManager.isPhoneReachable {
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.caption2)
                    Text("iPhone connected")
                        .font(.caption2)
                }
                .foregroundColor(.green)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Watch standalone mode")
                        .font(.caption2)
                }
                .foregroundColor(.purple)
            }

            // Emergency button - ALWAYS ENABLED
            Button {
                startEmergency()
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        // Pulsing background
                        Circle()
                            .fill(emergencyButtonColor.opacity(0.3))
                            .frame(width: 90, height: 90)
                            .scaleEffect(isPulsing ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                                value: isPulsing
                            )

                        // Main button
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: emergencyGradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: emergencyButtonColor.opacity(0.5), radius: 5)

                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Start Emergency")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(emergencyButtonColor)
                }
            }
            .buttonStyle(.plain)
            // NO LONGER DISABLED - works with or without iPhone!

            // Description based on mode
            Text(emergencyDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emergencyButtonColor: Color {
        connectivityManager.isPhoneReachable ? .red : .purple
    }

    private var emergencyGradientColors: [Color] {
        connectivityManager.isPhoneReachable
            ? [.red, .orange]
            : [.purple, .pink]
    }

    private var emergencyDescription: String {
        connectivityManager.isPhoneReachable
            ? "AI-powered cry detection & soothing music"
            : "Instant soothing sounds on Watch"
    }

    // MARK: - Active Emergency View

    private var activeEmergencyView: some View {
        VStack(spacing: 16) {
            // Active indicator
            ZStack {
                // Pulsing ring
                Circle()
                    .stroke(activeEmergencyColor.opacity(0.5), lineWidth: 4)
                    .frame(width: 90, height: 90)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: activeEmergencyGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                VStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Active")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            Text(activeEmergencyTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(activeEmergencyColor)

            // Current playback info
            if isStandaloneEmergencyActive {
                // Standalone mode - show Watch sound
                if let soundType = audioPlayer.currentStandaloneSound {
                    VStack(spacing: 2) {
                        Text("Now Playing:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: soundType.icon)
                                .font(.caption)
                            Text(soundType.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                    }
                }
            } else if let title = connectivityManager.iPhonePlaybackState.currentTrackTitle {
                // iPhone mode - show iPhone track
                VStack(spacing: 2) {
                    Text("Now Playing:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            // Stop button
            Button {
                stopEmergency()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
    }

    private var activeEmergencyColor: Color {
        isStandaloneEmergencyActive ? .purple : .purple
    }

    private var activeEmergencyGradient: [Color] {
        isStandaloneEmergencyActive
            ? [.purple, .pink]
            : [.purple, .blue]
    }

    private var activeEmergencyTitle: String {
        isStandaloneEmergencyActive
            ? "Watch Emergency Active"
            : "Emergency Mode Active"
    }

    // MARK: - Actions

    private func startEmergency() {
        if connectivityManager.isPhoneReachable {
            // iPhone available - use full AI-powered emergency mode WITH cry detection
            // This starts cry detection monitoring AND plays soothing music on iPhone
            connectivityManager.startEmergencyModeWithCryDetection()
        } else {
            // No iPhone - use standalone Watch emergency
            isStandaloneEmergencyActive = true
            audioPlayer.playEmergencyStandalone()
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private func stopEmergency() {
        if isStandaloneEmergencyActive {
            // Stop standalone mode
            audioPlayer.stop()
            isStandaloneEmergencyActive = false
        } else {
            // Stop iPhone mode
            connectivityManager.stopEmergencyMode()
        }
        WKInterfaceDevice.current().play(.stop)
    }
}

#Preview {
    EmergencyView()
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(WatchAudioPlayer.shared)
}

#Preview {
    EmergencyView()
        .environmentObject(WatchConnectivityManager.shared)
}
