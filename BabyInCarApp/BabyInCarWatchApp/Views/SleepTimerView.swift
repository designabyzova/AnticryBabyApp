import SwiftUI
import WatchKit

/// Sleep timer picker and status view
struct SleepTimerView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    @State private var selectedMinutes: Int = 15

    private let timerOptions = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if audioPlayer.sleepTimerActive {
                        activeTimerView
                    } else {
                        timerPickerView
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep Timer")
        }
    }

    // MARK: - Active Timer View

    private var activeTimerView: some View {
        VStack(spacing: 16) {
            // Timer icon with animation
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
                .symbolEffect(.pulse)

            // Remaining time
            Text(audioPlayer.formattedSleepTimer)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("Music will stop when timer ends")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Cancel button
            Button(role: .cancel) {
                cancelTimer()
            } label: {
                Label("Cancel Timer", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.top, 8)
        }
    }

    // MARK: - Timer Picker View

    private var timerPickerView: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "timer")
                .font(.system(size: 32))
                .foregroundColor(.purple)

            Text("Set Sleep Timer")
                .font(.headline)

            // Timer options grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(timerOptions, id: \.self) { minutes in
                    TimerOptionButton(
                        minutes: minutes,
                        isSelected: selectedMinutes == minutes,
                        onSelect: {
                            selectedMinutes = minutes
                            WKInterfaceDevice.current().play(.click)
                        }
                    )
                }
            }

            // Start button
            Button {
                startTimer()
            } label: {
                Label("Start Timer", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.top, 8)

            // Info text
            Text("Timer will also sync with iPhone")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func startTimer() {
        // Set timer on watch
        audioPlayer.setSleepTimer(minutes: selectedMinutes)

        // Sync to iPhone
        connectivityManager.setSleepTimer(minutes: selectedMinutes)

        WKInterfaceDevice.current().play(.success)
    }

    private func cancelTimer() {
        // Cancel on watch
        audioPlayer.cancelSleepTimer()

        // Sync to iPhone
        connectivityManager.cancelSleepTimer()

        WKInterfaceDevice.current().play(.click)
    }
}

// MARK: - Timer Option Button

struct TimerOptionButton: View {
    let minutes: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.headline)
                Text("min")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple : Color.gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SleepTimerView()
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(WatchAudioPlayer.shared)
}
