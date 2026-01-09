//
//  ProfileView.swift
//  BabyInCarApp
//
//  Profile and settings view
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    // FIX: Use @ObservedObject for singletons - prevents state recreation on orientation change
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var adaptiveLearning = AdaptiveLearningEngine.shared
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var showingEditBaby = false
    @State private var showingLanguageSelection = false
    @State private var showingSubscription = false
    @State private var showingResetConfirmation = false
    @State private var showingResetSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Baby profile card
                    babyProfileCard

                    // Premium banner (if not premium)
                    if !appState.isPremiumUser {
                        premiumBanner
                    }

                    // Settings sections
                    settingsSections
                }
                // Extra content padding at the bottom for comfortable scrolling.
                // The safeAreaInset in MainTabView handles the tab bar + mini player space.
                .padding(.bottom, 20)
            }
            .scrollIndicators(.visible)
            .background(Color.appBackground)
            .navigationTitle(languageManager.localizedString("nav.profile"))
        }
        .id(languageManager.refreshID) // Force refresh when language changes
        .sheet(isPresented: $showingEditBaby) {
            EditBabySheet()
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .alert("Reset Learning Data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                adaptiveLearning.resetAllLearning()
                showingResetSuccess = true
            }
        } message: {
            Text("This will clear all learned preferences about what sounds work best for your baby. The app will start fresh with no personalized recommendations.")
        }
        .alert("Learning Data Reset", isPresented: $showingResetSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All learning data has been cleared. The app will now learn your baby's preferences from scratch.")
        }
    }

    // MARK: - Baby Profile Card
    private var babyProfileCard: some View {
        VStack(spacing: 16) {
            // Baby avatar
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 100, height: 100)

                if let _ = appState.currentBaby?.photoData {
                    // Would display photo if available
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.appPrimary)
                } else {
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.appPrimary)
                }
            }

            VStack(spacing: 4) {
                Text(appState.currentBaby?.displayName ?? "Baby")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.appText)

                Text(appState.currentBaby?.formattedAge ?? "")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextSecondary)

                if let stage = appState.currentBaby?.developmentalStage {
                    Text(stage.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.appPrimary.opacity(0.1))
                        )
                }
            }

            Button {
                showingEditBaby = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text(languageManager.localizedString("profile.editProfile"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appPrimary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Premium Banner
    private var premiumBanner: some View {
        Button {
            showingSubscription = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text(languageManager.localizedString("profile.upgradeToPremium"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text(languageManager.localizedString("profile.unlockAllContent"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.appPrimary, Color.appSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Settings Sections
    private var settingsSections: some View {
        VStack(spacing: 20) {
            // Audio Settings
            SettingsSection(title: languageManager.localizedString("settings.audioSettings")) {
                SettingsRow(
                    icon: "speaker.wave.2.fill",
                    title: languageManager.localizedString("settings.defaultVolume"),
                    value: "\(Int(audioEngine.volume * 100))%"
                )

                SettingsRow(
                    icon: "clock.fill",
                    title: languageManager.localizedString("settings.sleepTimer"),
                    value: audioEngine.sleepTimer.displayName
                )

                SettingsToggleRow(
                    icon: "waveform.path",
                    title: languageManager.localizedString("settings.smoothTransitions"),
                    subtitle: languageManager.localizedString("settings.crossfadeTracks"),
                    isOn: Binding(
                        get: { appState.smoothTransitionsEnabled },
                        set: { appState.setSmoothTransitions($0) }
                    )
                )
                .accessibilityIdentifier("smoothTransitionsToggle")

                SettingsToggleRow(
                    icon: "car.fill",
                    title: "CarPlay",
                    isOn: .constant(true)
                )
            }

            // Cry Detection Settings (Auto-enabled by default for safety)
            SettingsSection(title: languageManager.localizedString("settings.cryDetection")) {
                SettingsToggleRow(
                    icon: "waveform.badge.exclamationmark",
                    title: languageManager.localizedString("settings.autoStartOnLaunch"),
                    isOn: Binding(
                        get: { appState.autoCryMonitoringEnabled },
                        set: { appState.setAutoCryMonitoring($0) }
                    )
                )

                NavigationLink(destination: CryDetectionView()) {
                    SettingsRow(
                        icon: "ear.and.waveform",
                        title: languageManager.localizedString("settings.cryDetectionSettings"),
                        value: EmergencyCryStopService.shared.isAIMonitoringEnabled ? languageManager.localizedString("home.active") : languageManager.localizedString("settings.ready"),
                        valueColor: EmergencyCryStopService.shared.isAIMonitoringEnabled ? .green : .secondary,
                        showChevron: true
                    )
                }
            }

            // Content Settings
            SettingsSection(title: languageManager.localizedString("settings.content")) {
                Button {
                    showingLanguageSelection = true
                } label: {
                    SettingsRow(
                        icon: "globe",
                        title: languageManager.localizedString("settings.languages"),
                        value: "\(languageManager.currentLanguage.flag) \(languageManager.currentLanguage.displayName)",
                        showChevron: true
                    )
                }

                NavigationLink(destination: DownloadsManagerView()) {
                    SettingsRowWithBadge(
                        icon: "arrow.down.circle.fill",
                        title: languageManager.localizedString("nav.downloads"),
                        showChevron: true
                    )
                }

                SettingsToggleRow(
                    icon: "mic.fill",
                    title: languageManager.localizedString("home.voiceControl"),
                    isOn: .constant(true)
                )
            }

            // App Settings
            SettingsSection(title: languageManager.localizedString("settings.app")) {
                NavigationLink(destination: AboutView()) {
                    SettingsRow(
                        icon: "info.circle.fill",
                        title: languageManager.localizedString("nav.about"),
                        showChevron: true
                    )
                }

                NavigationLink(destination: PrivacyPolicyView()) {
                    SettingsRow(
                        icon: "lock.shield.fill",
                        title: languageManager.localizedString("settings.privacyPolicy"),
                        showChevron: true
                    )
                }

                NavigationLink(destination: TermsView()) {
                    SettingsRow(
                        icon: "doc.text.fill",
                        title: languageManager.localizedString("settings.termsOfService"),
                        showChevron: true
                    )
                }

                Button {
                    // Contact support
                } label: {
                    SettingsRow(
                        icon: "envelope.fill",
                        title: languageManager.localizedString("settings.contactSupport"),
                        showChevron: true
                    )
                }
            }

            // Account
            SettingsSection(title: languageManager.localizedString("settings.account")) {
                if appState.isPremiumUser {
                    SettingsRow(
                        icon: "star.fill",
                        title: languageManager.localizedString("settings.subscription"),
                        value: "Premium",
                        valueColor: .appPrimary
                    )
                }

                Button {
                    // Restore purchases
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise",
                        title: languageManager.localizedString("settings.restorePurchases"),
                        showChevron: true
                    )
                }
            }

            // Data & Privacy
            SettingsSection(title: languageManager.localizedString("settings.dataPrivacy")) {
                // Show learning stats
                SettingsRow(
                    icon: "brain.head.profile",
                    title: languageManager.localizedString("settings.learningSessions"),
                    value: "\(adaptiveLearning.totalLearningSessions)"
                )

                SettingsRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: languageManager.localizedString("settings.learningConfidence"),
                    value: "\(Int(adaptiveLearning.learningConfidence * 100))%"
                )

                Button {
                    showingResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .frame(width: 32)

                        Text(languageManager.localizedString("settings.resetLearningData"))
                            .font(.system(size: 16))
                            .foregroundColor(.red)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }

            // Version info
            VStack(spacing: 4) {
                Text(languageManager.localizedString("app.tagline"))
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)

                Text("Version 1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(.appTextSecondary.opacity(0.7))
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = .appTextSecondary
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.appText)

            Spacer()

            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(valueColor)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.appText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.appPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, subtitle != nil ? 12 : 10)
    }
}

// MARK: - Settings Row with Badge (for Downloads)
struct SettingsRowWithBadge: View {
    let icon: String
    let title: String
    var showChevron: Bool = false
    @ObservedObject private var cacheService = AudioCacheService.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.appText)

            Spacer()

            // Show download count badge if there are downloads
            if let stats = cacheService.cacheStatistics, stats.totalTracks > 0 {
                Text("\(stats.totalTracks)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary)
                    )
            }

            // Show storage size
            if let stats = cacheService.cacheStatistics, stats.totalSize > 0 {
                Text(stats.formattedSize)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Edit Baby Sheet
struct EditBabySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section("Baby Information") {
                    TextField("Name", text: $name)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isNameFieldFocused = false
                        }

                    DatePicker(
                        "Birth Date",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section {
                    HStack {
                        Text("Current Age")
                        Spacer()
                        Text(calculatedAge)
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Baby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedBaby = Baby(
                            id: appState.currentBaby?.id ?? UUID(),
                            name: name,
                            birthDate: birthDate
                        )
                        appState.updateBaby(updatedBaby)
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isNameFieldFocused = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                }
            }
            .onAppear {
                if let baby = appState.currentBaby {
                    name = baby.name
                    birthDate = baby.birthDate
                }
            }
        }
    }

    private var calculatedAge: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        let months = components.month ?? 0

        if months == 0 {
            return "Newborn"
        } else if months == 1 {
            return "1 month old"
        } else {
            return "\(months) months old"
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "car.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.appPrimary)
                }
                .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("Lulla")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.appPrimary, .appSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Sweet Dreams on Every Ride")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appTextSecondary)

                    Text("Version 1.0.0")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary.opacity(0.7))
                }

                Text("AI-powered calming audio for peaceful car rides with your little one. Using age-personalized content, voice control, and our emergency cry-stop feature.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 16) {
                    FeatureAboutRow(icon: "waveform", title: "Age-Personalized Audio")
                    FeatureAboutRow(icon: "mic.fill", title: "Hands-Free Voice Control")
                    FeatureAboutRow(icon: "exclamationmark.triangle.fill", title: "Emergency Cry-Stop")
                    FeatureAboutRow(icon: "globe", title: "10+ Language Fairy Tales")
                }
                .padding(.top, 20)

                Spacer()
            }
        }
        .background(Color.appBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureAboutRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 32)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.appText)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("""
                Privacy Policy for Lulla

                Last updated: January 2026

                We take your privacy seriously. This app is designed with children's safety in mind and complies with COPPA and GDPR-K requirements.

                Data We Collect:
                • Baby's name and birth date (for personalization)
                • Selected language preferences
                • Listening history (stored locally)

                Data We DO NOT Collect:
                • Location data
                • Personal identifiable information
                • Advertising identifiers
                • Third-party analytics data

                Children's Privacy:
                This app does not collect personal information from children. All baby profile data is stored locally on your device and is not transmitted to our servers.

                Data Storage:
                All user data is stored locally on your device using secure storage methods. No data is transmitted to external servers.

                Contact:
                For any privacy concerns, please contact us at privacy@lulla.app
                """)
                .font(.system(size: 14))
                .foregroundColor(.appText)
                .padding()
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms View
struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("""
                Terms of Service for Lulla

                Last updated: January 2026

                By using this app, you agree to the following terms:

                1. Use of Service
                This app is designed to help calm babies during car travel. It is not a substitute for proper child care and supervision.

                2. Safety Notice
                Never let this app distract you from safe driving. Always keep your eyes on the road. Use voice controls when possible.

                3. Audio Safety
                The app limits maximum volume to protect your baby's hearing (maximum 50dB). Do not attempt to bypass these safety measures.

                4. Subscriptions
                Premium features require a subscription. You can cancel at any time through your App Store settings.

                5. Content
                All audio content is either generated by the app or sourced from royalty-free libraries. We do not guarantee the effectiveness of any specific sound for calming your baby.

                6. Disclaimer
                This app is provided "as is" without warranties. We are not responsible for any issues arising from the use of this app.

                Contact:
                For questions, please contact support@lulla.app
                """)
                .font(.system(size: 14))
                .foregroundColor(.appText)
                .padding()
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
}
