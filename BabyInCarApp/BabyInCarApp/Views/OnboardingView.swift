//
//  OnboardingView.swift
//  BabyInCarApp
//
//  Onboarding flow for new users
//

import SwiftUI
import AVFoundation
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var babyName = ""
    @State private var babyBirthDate = Date()
    @State private var selectedLanguages: Set<Language> = [.english]
    @State private var showingDatePicker = false
    @State private var showingVoiceInput = false

    let totalPages = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.appPrimary.opacity(0.1), Color.appSecondary.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator - respects safe area
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index <= currentPage ? Color.appPrimary : Color.appPrimary.opacity(0.3))
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? 16 : 50) // Extra padding for status bar

                    // Content
                    TabView(selection: $currentPage) {
                        WelcomePage()
                            .tag(0)

                        BabyInfoPage(
                            name: $babyName,
                            birthDate: $babyBirthDate,
                            showingDatePicker: $showingDatePicker,
                            showingVoiceInput: $showingVoiceInput
                        )
                        .tag(1)

                        LanguageSelectionPage(selectedLanguages: $selectedLanguages)
                            .tag(2)

                        PermissionsPage()
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentPage)

                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button {
                                hideKeyboard()
                                withAnimation {
                                    currentPage -= 1
                                }
                            } label: {
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.appTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.appTextSecondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }

                        Button {
                            hideKeyboard()
                            if currentPage < totalPages - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                completeOnboarding()
                            }
                        } label: {
                            Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isNextEnabled ? Color.appPrimary : Color.appPrimary.opacity(0.5))
                                )
                        }
                        .disabled(!isNextEnabled)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 20)
                }
            }
        }
        .ignoresSafeArea(.keyboard) // Allow keyboard to overlap content naturally
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var isNextEnabled: Bool {
        switch currentPage {
        case 1:
            return !babyName.isEmpty
        case 2:
            return !selectedLanguages.isEmpty
        default:
            return true
        }
    }

    private func completeOnboarding() {
        let baby = Baby(name: babyName, birthDate: babyBirthDate)
        appState.completeOnboarding(baby: baby, languages: Array(selectedLanguages))
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "car.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.appPrimary)
                    .overlay(
                        Image(systemName: "face.smiling.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appSecondary)
                            .offset(x: 30, y: -30)
                    )
            }

            VStack(spacing: 12) {
                Text("Baby in Car")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.appText)

                Text("Without Tears")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.appSecondary)
            }

            Text("AI-powered calming audio for peaceful car rides with your little one")
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Feature highlights
            VStack(spacing: 16) {
                FeatureRow(icon: "waveform", text: "Age-personalized audio content")
                FeatureRow(icon: "mic.fill", text: "Hands-free voice control")
                FeatureRow(icon: "exclamationmark.triangle.fill", text: "Emergency cry-stop feature")
                FeatureRow(icon: "globe", text: "10+ language fairy tales")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.appText)

            Spacer()
        }
    }
}

// MARK: - Baby Info Page
struct BabyInfoPage: View {
    @Binding var name: String
    @Binding var birthDate: Date
    @Binding var showingDatePicker: Bool
    @Binding var showingVoiceInput: Bool

    @StateObject private var speechService = SpeechRecognitionService.shared
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Text("Tell us about your baby")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.appText)

                Text("We'll personalize content based on your baby's age")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 20)

                VStack(spacing: 20) {
                    // Baby name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Baby's Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextSecondary)

                        TextField("Enter baby's name", text: $name)
                            .font(.system(size: 16))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.05), radius: 4)
                            )
                            .focused($isNameFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                isNameFieldFocused = false
                            }
                    }

                    // Birth date input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birth Date")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextSecondary)

                        Button {
                            isNameFieldFocused = false
                            showingDatePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.appPrimary)

                                Text(birthDate.formatted(date: .long, time: .omitted))
                                    .foregroundColor(.appText)

                                Spacer()

                                Text(calculatedAge)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appPrimary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.05), radius: 4)
                            )
                        }
                    }

                    // Voice input option
                    VStack(spacing: 12) {
                        Text("Or use voice")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)

                        Button {
                            isNameFieldFocused = false
                            showingVoiceInput = true
                        } label: {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Say baby's age")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appPrimary, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 100) // Extra space for keyboard
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isNameFieldFocused = false
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(date: $birthDate)
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputSheet(birthDate: $birthDate)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNameFieldFocused = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appPrimary)
            }
        }
    }

    private var calculatedAge: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: birthDate, to: Date())
        let months = components.month ?? 0

        if months == 0 {
            let days = components.day ?? 0
            return "\(days) days old"
        } else if months == 1 {
            return "1 month old"
        } else {
            return "\(months) months old"
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Birth Date",
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Select Birth Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @Binding var birthDate: Date
    @StateObject private var speechService = SpeechRecognitionService.shared
    @Environment(\.dismiss) var dismiss
    @State private var recognizedAge: Int?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Microphone animation
                ZStack {
                    Circle()
                        .fill(speechService.isListening ? Color.appPrimary.opacity(0.2) : Color.clear)
                        .frame(width: 150, height: 150)
                        .scaleEffect(speechService.isListening ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speechService.isListening)

                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 100, height: 100)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }

                Text(speechService.isListening ? "Listening..." : "Tap to speak")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.appText)

                Text("Say something like:\n\"My baby is 5 months old\"")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)

                if !speechService.recognizedText.isEmpty {
                    VStack(spacing: 8) {
                        Text("I heard:")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)

                        Text(speechService.recognizedText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appPrimary.opacity(0.1))
                            )
                    }
                    .padding(.horizontal)
                }

                if let age = recognizedAge {
                    Text("Detected age: \(age) months old")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appSuccess)
                }

                Spacer()

                // Listen button
                Button {
                    if speechService.isListening {
                        speechService.stopListening()
                        processRecognizedText()
                    } else {
                        speechService.startListening()
                    }
                } label: {
                    Text(speechService.isListening ? "Stop" : "Start Listening")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(speechService.isListening ? Color.appDanger : Color.appPrimary)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechService.stopListening()
                        dismiss()
                    }
                }

                if recognizedAge != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            if let age = recognizedAge {
                                let calendar = Calendar.current
                                birthDate = calendar.date(byAdding: .month, value: -age, to: Date()) ?? Date()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func processRecognizedText() {
        if let age = speechService.extractAge(from: speechService.recognizedText) {
            recognizedAge = age
        }
    }
}

// MARK: - Language Selection Page
struct LanguageSelectionPage: View {
    @Binding var selectedLanguages: Set<Language>

    var body: some View {
        VStack(spacing: 24) {
            Text("Select Languages")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.appText)

            Text("Choose languages for fairy tales and stories")
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Language.allCases) { language in
                        LanguageCard(
                            language: language,
                            isSelected: selectedLanguages.contains(language)
                        ) {
                            if selectedLanguages.contains(language) {
                                if selectedLanguages.count > 1 {
                                    selectedLanguages.remove(language)
                                }
                            } else {
                                selectedLanguages.insert(language)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 40)
    }
}

struct LanguageCard: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 36))

                Text(language.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .appText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.appPrimary : Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Permissions Page
struct PermissionsPage: View {
    @State private var microphoneGranted = false
    @State private var notificationsGranted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.appPrimary)

            Text("Almost Ready!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.appText)

            Text("We need a few permissions to give you the best experience")
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "For hands-free voice control while driving",
                    isGranted: microphoneGranted
                ) {
                    requestMicrophonePermission()
                }

                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "For sleep timer and playback alerts",
                    isGranted: notificationsGranted
                ) {
                    requestNotificationPermission()
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text("You can change these later in Settings")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check microphone permission
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphoneGranted = true
        default:
            microphoneGranted = false
        }
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                microphoneGranted = granted
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                notificationsGranted = granted
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.appPrimary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appSuccess)
            } else {
                Button("Allow") {
                    action()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.appPrimary)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
