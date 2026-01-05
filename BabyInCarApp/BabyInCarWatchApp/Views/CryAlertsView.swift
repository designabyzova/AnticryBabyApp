import SwiftUI
import WatchKit

/// Shows cry detection alerts received from iPhone
struct CryAlertsView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    var body: some View {
        NavigationStack {
            Group {
                if connectivityManager.pendingCryAlerts.isEmpty {
                    emptyStateView
                } else {
                    alertsListView
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                if !connectivityManager.pendingCryAlerts.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") {
                            connectivityManager.dismissAllAlerts()
                            WKInterfaceDevice.current().play(.click)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Alerts List

    private var alertsListView: some View {
        List {
            ForEach(connectivityManager.pendingCryAlerts) { alert in
                CryAlertRowView(
                    alert: alert,
                    onPlayMusic: {
                        playSoothingMusic(for: alert)
                    },
                    onDismiss: {
                        connectivityManager.dismissAlert(alert)
                    }
                )
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if !connectivityManager.isPhoneReachable {
                // Prominent warning when iPhone disconnected
                VStack(spacing: 8) {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                        .symbolEffect(.pulse)

                    Text("iPhone Required")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("Apple Watch cannot detect baby cries independently. Keep your iPhone nearby with the app running.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                // Normal empty state
                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundColor(.green)

                Text("No Alerts")
                    .font(.headline)

                Text("You'll see cry alerts here when your baby needs attention")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Info about iPhone requirement
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text("iPhone detects cries")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)

                    Text("Alerts sent to watch instantly")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func playSoothingMusic(for alert: CryAlert) {
        // Start soothing music based on cry type
        connectivityManager.startSoothingMusic(playlistId: alert.suggestedPlaylistId)
        WKInterfaceDevice.current().play(.success)
    }
}

// MARK: - Cry Alert Row

struct CryAlertRowView: View {
    let alert: CryAlert
    let onPlayMusic: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Header with icon and type
            HStack {
                Image(systemName: alert.cryType.iconName)
                    .font(.title2)
                    .foregroundColor(colorForCryType(alert.cryType))

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.cryType.displayName)
                        .font(.headline)

                    Text(alert.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Confidence indicator
                confidenceIndicator(alert.confidence)
            }

            // Suggested action
            Text(alert.suggestedAction)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onPlayMusic()
                } label: {
                    Label("Play Music", systemImage: "music.note")
                        .font(.caption2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func confidenceIndicator(_ confidence: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)

            Circle()
                .trim(from: 0, to: confidence)
                .stroke(confidenceColor(confidence), lineWidth: 2)
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))

            Text("\(Int(confidence * 100))")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }

    private func colorForCryType(_ type: CryType) -> Color {
        switch type {
        case .pain: return .red
        case .hunger: return .orange
        case .tired: return .purple
        case .attention: return .yellow
        case .discomfort: return .pink
        case .general, .unknown: return .blue
        }
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .yellow
        } else {
            return .orange
        }
    }
}

#Preview {
    CryAlertsView()
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(WatchAudioPlayer.shared)
}
