//
//  Accessibility.swift
//  BabyInCarApp
//
//  Accessibility support for VoiceOver, Reduce Motion, and contrast compliance
//

import SwiftUI

// MARK: - Accessibility Manager

/// Manages accessibility settings and preferences
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    /// Whether reduced motion is enabled in system settings
    @Published var reduceMotion: Bool = false

    /// Whether VoiceOver is running
    @Published var voiceOverRunning: Bool = false

    /// Whether bold text is enabled
    @Published var boldTextEnabled: Bool = false

    /// Current dynamic type size category
    @Published var dynamicTypeSize: DynamicTypeSize = .medium

    private init() {
        updateSettings()
        setupNotifications()
    }

    private func updateSettings() {
        reduceMotion = UIAccessibility.isReduceMotionEnabled
        voiceOverRunning = UIAccessibility.isVoiceOverRunning
        boldTextEnabled = UIAccessibility.isBoldTextEnabled
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reduceMotion = UIAccessibility.isReduceMotionEnabled
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.voiceOverRunning = UIAccessibility.isVoiceOverRunning
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.boldTextEnabled = UIAccessibility.isBoldTextEnabled
        }
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    /// Add comprehensive accessibility label and hint
    func accessibleButton(label: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .onTapGesture(perform: action)
    }

    /// Add accessibility for playback controls
    func accessiblePlaybackControl(
        isPlaying: Bool,
        trackTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        self
            .accessibilityLabel(isPlaying ? "Pause \(trackTitle)" : "Play \(trackTitle)")
            .accessibilityHint(isPlaying ? "Double tap to pause" : "Double tap to play")
            .accessibilityAddTraits(.isButton)
            .onTapGesture(perform: action)
    }

    /// Add accessibility for sliders/progress bars
    func accessibleProgress(
        label: String,
        value: Double,
        total: Double,
        unit: String = ""
    ) -> some View {
        let percentage = total > 0 ? Int((value / total) * 100) : 0
        let formattedValue = formatAccessibleTime(value)
        let formattedTotal = formatAccessibleTime(total)

        return self
            .accessibilityLabel("\(label), \(formattedValue) of \(formattedTotal)")
            .accessibilityValue("\(percentage) percent \(unit)")
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Add accessibility for images
    func accessibleImage(label: String, isDecorative: Bool = false) -> some View {
        if isDecorative {
            return AnyView(self.accessibilityHidden(true))
        }
        return AnyView(
            self
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
        )
    }

    /// Add accessibility for category cards
    func accessibleCategoryCard(
        category: String,
        trackCount: Int,
        isSelected: Bool = false
    ) -> some View {
        self
            .accessibilityLabel("\(category) category, \(trackCount) tracks")
            .accessibilityHint("Double tap to browse \(category)")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Add accessibility for track cards
    func accessibleTrackCard(
        title: String,
        artist: String,
        duration: String,
        isPlaying: Bool = false,
        isFavorite: Bool = false
    ) -> some View {
        var label = "\(title) by \(artist), \(duration)"
        if isPlaying {
            label += ", currently playing"
        }
        if isFavorite {
            label += ", favorited"
        }

        return self
            .accessibilityLabel(label)
            .accessibilityHint("Double tap to play")
            .accessibilityAddTraits(isPlaying ? [.isButton, .isSelected] : .isButton)
    }

    /// Simplified animation for reduced motion
    func reducedMotionAnimation<V: Equatable>(
        _ animation: Animation? = .default,
        value: V
    ) -> some View {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        return self.animation(reduceMotion ? nil : animation, value: value)
    }

    /// Apply animation only when reduce motion is disabled
    func conditionalAnimation(_ animation: Animation?) -> some View {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if reduceMotion {
            return AnyView(self)
        }
        return AnyView(self.animation(animation))
    }
}

// MARK: - Accessibility Helper Functions

/// Format time for VoiceOver reading
func formatAccessibleTime(_ seconds: Double) -> String {
    let minutes = Int(seconds) / 60
    let secs = Int(seconds) % 60

    if minutes == 0 {
        return "\(secs) seconds"
    } else if minutes == 1 {
        return "1 minute \(secs) seconds"
    } else {
        return "\(minutes) minutes \(secs) seconds"
    }
}

/// Format percentage for VoiceOver
func formatAccessiblePercentage(_ value: Double) -> String {
    let percentage = Int(value * 100)
    return "\(percentage) percent"
}

// MARK: - Accessible Animation Wrapper

/// Wrapper that respects Reduce Motion setting
struct AccessibleAnimation<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let animation: Animation?
    let content: () -> Content

    init(
        animation: Animation? = .default,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.animation = animation
        self.content = content
    }

    var body: some View {
        if reduceMotion {
            content()
        } else {
            content()
                .animation(animation)
        }
    }
}

// MARK: - Accessible Button Style

/// Button style that provides clear visual feedback and accessibility
struct AccessibleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.95 : 1.0))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - High Contrast Colors

extension Color {
    /// High contrast text color for accessibility
    static let highContrastText = Color(UIColor { traitCollection in
        traitCollection.accessibilityContrast == .high ?
            UIColor.label : UIColor(Color.appText)
    })

    /// High contrast secondary text
    static let highContrastSecondaryText = Color(UIColor { traitCollection in
        traitCollection.accessibilityContrast == .high ?
            UIColor.secondaryLabel : UIColor(Color.appTextSecondary)
    })

    /// High contrast primary color
    static let highContrastPrimary = Color(UIColor { traitCollection in
        traitCollection.accessibilityContrast == .high ?
            UIColor.systemPurple : UIColor(Color.appPrimary)
    })
}

// MARK: - Accessibility Announcement Helper

/// Helper to make VoiceOver announcements
struct AccessibilityAnnouncement {
    /// Announce a message to VoiceOver users
    static func announce(_ message: String, priority: UIAccessibility.Announcement.Priority = .low) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Announce that screen content has changed
    static func screenChanged() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    /// Announce that layout has changed
    static func layoutChanged(focusElement: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: focusElement)
    }
}

// MARK: - Previews

#Preview("Accessibility Controls") {
    VStack(spacing: 20) {
        Button("Play Track") {}
            .accessibleButton(label: "Play Track", hint: "Double tap to start playback")
            .buttonStyle(AccessibleButtonStyle())

        Button("Pause") {}
            .accessiblePlaybackControl(isPlaying: true, trackTitle: "Lullaby") {}

        ProgressView(value: 0.5)
            .accessibleProgress(label: "Playback progress", value: 90, total: 180)
    }
    .padding()
}
