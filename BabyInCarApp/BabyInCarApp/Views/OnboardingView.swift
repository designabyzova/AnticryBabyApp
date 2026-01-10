//
//  OnboardingView.swift
//  BabyInCarApp
//
//  Premium onboarding flow with delightful animations
//

import SwiftUI
import AVFoundation
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var currentPage = 0
    @State private var babyName = ""
    @State private var babyBirthDate = Date()
    @State private var selectedLanguage: SupportedLanguage = LanguageManager.shared.currentLanguage
    @State private var showingDatePicker = false
    @State private var parallaxOffset: CGFloat = 0

    let totalPages = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated parallax background
                OnboardingBackground(currentPage: currentPage, parallaxOffset: parallaxOffset)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Playful progress indicator
                    OnboardingProgressIndicator(currentPage: currentPage, totalPages: totalPages)
                        .padding(.horizontal, 24)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 16 : 50)

                    // Content with parallax
                    TabView(selection: $currentPage) {
                        WelcomePage()
                            .tag(0)

                        BabyInfoPage(
                            name: $babyName,
                            birthDate: $babyBirthDate,
                            showingDatePicker: $showingDatePicker
                        )
                        .tag(1)

                        OnboardingLanguageSelectionPage(selectedLanguage: $selectedLanguage)
                            .tag(2)

                        PermissionsPage()
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)

                    // Premium navigation buttons
                    OnboardingNavigationButtons(
                        currentPage: $currentPage,
                        totalPages: totalPages,
                        isNextEnabled: isNextEnabled,
                        onComplete: completeOnboarding
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 20)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var isNextEnabled: Bool {
        switch currentPage {
        case 1:
            return !babyName.isEmpty
        default:
            return true
        }
    }

    private func completeOnboarding() {
        let baby = Baby(name: babyName, birthDate: babyBirthDate)
        // Set the selected language
        languageManager.setLanguage(selectedLanguage)
        appState.completeOnboarding(baby: baby, language: selectedLanguage)
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var featuresOpacity: Double = 0
    @State private var floatingOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: DesignTokens.spacingL) {
            Spacer()

            // Animated logo illustration
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appPrimary.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(1.0 + floatingOffset * 0.01)

                // Main circle with gradient
                Circle()
                    .fill(Color.dreamyGradient)
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.appPrimary.opacity(0.3), radius: 20, x: 0, y: 10)

                // Inner illustration
                WelcomeIllustration()
                    .offset(y: floatingOffset)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            // App name with gradient text
            VStack(spacing: DesignTokens.spacingS) {
                Text("Lulla")
                    .font(.appDisplay)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appPrimary, .appSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Calm Baby, Anywhere")
                    .font(.appTitle3)
                    .foregroundColor(.appTextSecondary)
            }
            .offset(y: titleOffset)
            .opacity(titleOpacity)

            Text("AI-powered calming audio for peaceful car rides with your little one")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .offset(y: titleOffset)
                .opacity(titleOpacity)

            Spacer()

            // Animated feature highlights
            VStack(spacing: DesignTokens.spacingM) {
                AnimatedFeatureRow(icon: "waveform", text: "Age-personalized audio content", delay: 0)
                AnimatedFeatureRow(icon: "exclamationmark.triangle.fill", text: "Emergency cry-stop feature", delay: 0.1)
                AnimatedFeatureRow(icon: "globe", text: "10+ language fairy tales", delay: 0.2)
                AnimatedFeatureRow(icon: "car.fill", text: "CarPlay ready for safe driving", delay: 0.3)
            }
            .padding(.horizontal, 24)
            .opacity(featuresOpacity)

            Spacer()
        }
        .onAppear {
            // Staggered entrance animations
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                featuresOpacity = 1.0
            }
        }
        // FIX: Use task with stable ID for floating animation to prevent restart on orientation change
        .task(id: "floating-animation") {
            if floatingOffset == 0 {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    floatingOffset = -8
                }
            }
        }
    }
}

// MARK: - Welcome Illustration
struct WelcomeIllustration: View {
    @State private var noteOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        ZStack {
            // Sleeping baby face
            VStack(spacing: 4) {
                // Closed eyes
                HStack(spacing: 18) {
                    ClosedEyeShape()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 16, height: 8)
                    ClosedEyeShape()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 16, height: 8)
                }

                // Cheeks
                HStack(spacing: 30) {
                    Circle()
                        .fill(Color.appAccentCoral.opacity(0.6))
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.appAccentCoral.opacity(0.6))
                        .frame(width: 12, height: 12)
                }
                .offset(y: -2)

                // Smile
                SmileShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 18, height: 8)
            }

            // Floating music notes
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(
                        x: CGFloat([35, -35, 0][index]),
                        y: CGFloat([-40, -35, -50][index]) + noteOffsets[index]
                    )
            }
        }
        // FIX: Use task with stable ID for note animations to prevent restart on orientation change
        .task(id: "note-animations") {
            // Only start if not already animating
            if noteOffsets[0] == 0 {
                for i in 0..<3 {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                        noteOffsets[i] = -8
                    }
                }
            }
        }
    }
}

// MARK: - Animated Feature Row
struct AnimatedFeatureRow: View {
    let icon: String
    let text: String
    let delay: Double

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appPrimary)
            }

            Text(text)
                .font(.appBody)
                .foregroundColor(.appText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.appAccentMint)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.5)
        }
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .offset(x: isVisible ? 0 : -20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay + 0.8)) {
                isVisible = true
            }
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

// MARK: - Onboarding Language Selection Page (Single Select)
struct OnboardingLanguageSelectionPage: View {
    @Binding var selectedLanguage: SupportedLanguage
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Text(languageManager.localizedString("language.chooseYourLanguage"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.appText)

            Text(languageManager.localizedString("language.selectInterfaceLanguage"))
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(SupportedLanguage.allCases) { language in
                        OnboardingLanguageCard(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedLanguage = language
                                // Update language manager immediately for preview
                                languageManager.setLanguage(language)
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 40)
        .id(languageManager.refreshID) // Force refresh when language changes
    }
}

struct OnboardingLanguageCard: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 36))

                Text(language.displayName)
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
                    description: "For AI cry detection and monitoring",
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

// MARK: - Onboarding Background
struct OnboardingBackground: View {
    var currentPage: Int
    var parallaxOffset: CGFloat

    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )

            // Floating decorations
            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color.appPrimary.opacity(0.05))
                        .frame(width: CGFloat.random(in: 40...120))
                        .offset(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height) + parallaxOffset * CGFloat(index + 1) * 0.1
                        )
                }
            }
        }
        // FIX: Use task with stable ID for gradient animation to prevent restart on orientation change
        .task(id: "gradient-animation") {
            if !animateGradient {
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
        }
    }

    private var backgroundColors: [Color] {
        switch currentPage {
        case 0:
            return [Color.appWarmCream, Color.appPrimary.opacity(0.1), Color.appSecondary.opacity(0.05)]
        case 1:
            return [Color.appSecondary.opacity(0.1), Color.appWarmCream, Color.appPrimary.opacity(0.05)]
        case 2:
            return [Color.appPrimary.opacity(0.1), Color.appWarmCream, Color.appAccentMint.opacity(0.1)]
        case 3:
            return [Color.appAccentMint.opacity(0.1), Color.appWarmCream, Color.appPrimary.opacity(0.1)]
        default:
            return [Color.appWarmCream, Color.appPrimary.opacity(0.1)]
        }
    }
}

// MARK: - Onboarding Progress Indicator
struct OnboardingProgressIndicator: View {
    var currentPage: Int
    var totalPages: Int

    var body: some View {
        HStack(spacing: DesignTokens.spacingS) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? Color.appPrimary : Color.appPrimary.opacity(0.2))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
}

// MARK: - Onboarding Navigation Buttons
struct OnboardingNavigationButtons: View {
    @Binding var currentPage: Int
    var totalPages: Int
    var isNextEnabled: Bool
    var onComplete: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Back button
            if currentPage > 0 {
                Button {
                    hideKeyboard()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage -= 1
                    }
                } label: {
                    HStack(spacing: DesignTokens.spacingS) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.appBodyMedium)
                    }
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                            .stroke(Color.appTextTertiary, lineWidth: 1.5)
                    )
                }
                .buttonStyle(BounceButtonStyle())
            }

            // Continue / Get Started button
            Button {
                hideKeyboard()
                if currentPage < totalPages - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    onComplete()
                }
            } label: {
                HStack(spacing: DesignTokens.spacingS) {
                    Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                        .font(.appBodyMedium)

                    if currentPage < totalPages - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                        .fill(
                            isNextEnabled ?
                                LinearGradient(
                                    colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.4), Color.appPrimary.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                )
                .shadow(color: isNextEnabled ? Color.appPrimary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(!isNextEnabled)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Bounce Button Style
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
