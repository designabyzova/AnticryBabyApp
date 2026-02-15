//
//  VoiceInteractionSettingsView.swift
//  BabyInCarApp
//
//  Settings for voice interaction and hands-free mode
//

import SwiftUI

// MARK: - Settings Model

/// Programmatic access to voice interaction settings stored in UserDefaults.
/// Views should use @AppStorage directly; services use this struct.
struct VoiceInteractionSettings {
    static var handsFreeModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "handsFreeModeEnabled")
    }

    static var voicePromptsEnabled: Bool {
        UserDefaults.standard.object(forKey: "voicePromptsEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "voicePromptsEnabled")
    }

    static var voiceResponsesEnabled: Bool {
        UserDefaults.standard.object(forKey: "voiceResponsesEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "voiceResponsesEnabled")
    }

    static var voiceVolume: Float {
        let val = UserDefaults.standard.float(forKey: "voiceVolume")
        return val == 0 ? 0.8 : val
    }

    static var autoEnableInCarPlay: Bool {
        UserDefaults.standard.object(forKey: "autoEnableInCarPlay") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "autoEnableInCarPlay")
    }
}

// MARK: - Settings View

struct VoiceInteractionSettingsView: View {
    @AppStorage("handsFreeModeEnabled") private var handsFreeModeEnabled = false
    @AppStorage("voicePromptsEnabled") private var voicePromptsEnabled = true
    @AppStorage("voiceResponsesEnabled") private var voiceResponsesEnabled = true
    @AppStorage("voiceVolume") private var voiceVolume: Double = 0.8
    @AppStorage("autoEnableInCarPlay") private var autoEnableInCarPlay = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hands-Free Mode
                SettingsSection(title: "Hands-Free Mode") {
                    SettingsToggleRow(
                        icon: "hand.raised.slash.fill",
                        title: "Enable Hands-Free Mode",
                        subtitle: "When enabled, the app will use voice prompts instead of touch interactions.",
                        isOn: $handsFreeModeEnabled
                    )
                    .accessibilityIdentifier("handsFreeModeToggle")
                }

                // Voice Settings
                SettingsSection(title: "Voice Settings") {
                    SettingsToggleRow(
                        icon: "speaker.wave.2.fill",
                        title: "Voice Prompts",
                        subtitle: "Speak questions and announcements aloud",
                        isOn: $voicePromptsEnabled
                    )
                    .accessibilityIdentifier("voicePromptsToggle")

                    SettingsToggleRow(
                        icon: "mic.fill",
                        title: "Voice Responses",
                        subtitle: "Listen for yes/no voice answers",
                        isOn: $voiceResponsesEnabled
                    )
                    .accessibilityIdentifier("voiceResponsesToggle")

                    if voiceResponsesEnabled {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "speaker.wave.1.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.appPrimary)
                                    .frame(width: 28)

                                Text("Voice Volume")
                                    .font(.system(size: 15))
                                    .foregroundColor(.appText)

                                Spacer()

                                Text("\(Int(voiceVolume * 100))%")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appTextSecondary)
                            }

                            Slider(value: $voiceVolume, in: 0.3...1.0, step: 0.05)
                                .tint(.appPrimary)
                                .accessibilityIdentifier("voiceVolumeSlider")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                // CarPlay
                SettingsSection(title: "CarPlay") {
                    SettingsToggleRow(
                        icon: "car.fill",
                        title: "Auto-enable in CarPlay",
                        subtitle: "Automatically enables hands-free mode when CarPlay connects.",
                        isOn: $autoEnableInCarPlay
                    )
                    .accessibilityIdentifier("autoEnableCarPlayToggle")
                }

                // Permissions
                SettingsSection(title: "Permissions") {
                    Button {
                        openAppSettings()
                    } label: {
                        SettingsRow(
                            icon: "gear",
                            title: "Configure Speech Recognition",
                            showChevron: true
                        )
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.appBackground)
        .navigationTitle("Voice & Hands-Free")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        VoiceInteractionSettingsView()
    }
}
