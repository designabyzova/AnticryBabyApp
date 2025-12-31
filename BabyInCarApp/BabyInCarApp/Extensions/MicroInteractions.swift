//
//  MicroInteractions.swift
//  BabyInCarApp
//
//  Polished micro-interactions, haptic feedback patterns, and animation refinements
//

import SwiftUI
import UIKit

// MARK: - Haptic Manager

/// Centralized haptic feedback manager for consistent tactile responses
class HapticManager {
    static let shared = HapticManager()

    // Pre-configured generators for different feedback types
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        prepareAll()
    }

    /// Prepare all generators for quick response
    func prepareAll() {
        selectionGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        softImpactGenerator.prepare()
        rigidImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Standard Feedback Types

    /// Selection change (tabs, toggles, options)
    func selection() {
        selectionGenerator.selectionChanged()
    }

    /// Light tap (buttons, icons)
    func lightTap() {
        lightImpactGenerator.impactOccurred()
    }

    /// Medium tap (play/pause, important actions)
    func mediumTap() {
        mediumImpactGenerator.impactOccurred()
    }

    /// Heavy tap (emergency button, confirm actions)
    func heavyTap() {
        heavyImpactGenerator.impactOccurred()
    }

    /// Soft feedback (drag, smooth interactions)
    func soft() {
        softImpactGenerator.impactOccurred()
    }

    /// Rigid feedback (slider endpoints, limits)
    func rigid() {
        rigidImpactGenerator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success feedback (completed, downloaded)
    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Warning feedback (attention needed)
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Error feedback (failed action)
    func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    // MARK: - Custom Patterns

    /// Double tap pattern for emphasis
    func doubleTap() {
        lightImpactGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.lightImpactGenerator.impactOccurred()
        }
    }

    /// Heartbeat pattern (for emergency or attention)
    func heartbeat() {
        heavyImpactGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.mediumImpactGenerator.impactOccurred()
        }
    }

    /// Slider tick feedback
    func sliderTick(intensity: CGFloat = 0.5) {
        lightImpactGenerator.impactOccurred(intensity: intensity)
    }

    /// Progress complete feedback
    func progressComplete() {
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lightImpactGenerator.impactOccurred()
        }
    }
}

// MARK: - Micro-Interaction View Modifiers

extension View {
    /// Scale and haptic feedback on tap
    func tapWithFeedback(
        scale: CGFloat = 0.95,
        haptic: HapticType = .light,
        action: @escaping () -> Void
    ) -> some View {
        modifier(TapFeedbackModifier(scale: scale, haptic: haptic, action: action))
    }

    /// Highlight effect on press
    func highlightOnPress(color: Color = .appPrimary) -> some View {
        modifier(HighlightOnPressModifier(highlightColor: color))
    }

    /// Bounce animation on appear
    func bounceOnAppear(delay: Double = 0) -> some View {
        modifier(BounceOnAppearModifier(delay: delay))
    }

    /// Shimmer loading effect
    func shimmerEffect(isActive: Bool = true) -> some View {
        modifier(ShimmerEffectModifier(isActive: isActive))
    }

    /// Glow effect
    func glowEffect(color: Color = .appPrimary, isActive: Bool = true) -> some View {
        modifier(GlowEffectModifier(glowColor: color, isActive: isActive))
    }

    /// Floating animation
    func floatingAnimation(offset: CGFloat = 5, duration: Double = 2) -> some View {
        modifier(FloatingAnimationModifier(offset: offset, duration: duration))
    }

    /// Press and hold feedback
    func pressAndHold(onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        modifier(PressAndHoldModifier(onStart: onStart, onEnd: onEnd))
    }
}

// MARK: - Haptic Type Enum

enum HapticType {
    case none
    case selection
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error

    func trigger() {
        switch self {
        case .none: break
        case .selection: HapticManager.shared.selection()
        case .light: HapticManager.shared.lightTap()
        case .medium: HapticManager.shared.mediumTap()
        case .heavy: HapticManager.shared.heavyTap()
        case .soft: HapticManager.shared.soft()
        case .rigid: HapticManager.shared.rigid()
        case .success: HapticManager.shared.success()
        case .warning: HapticManager.shared.warning()
        case .error: HapticManager.shared.error()
        }
    }
}

// MARK: - View Modifier Implementations

struct TapFeedbackModifier: ViewModifier {
    let scale: CGFloat
    let haptic: HapticType
    let action: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            haptic.trigger()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

struct HighlightOnPressModifier: ViewModifier {
    let highlightColor: Color

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                    .fill(highlightColor.opacity(isPressed ? 0.1 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct BounceOnAppearModifier: ViewModifier {
    let delay: Double

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .spring(response: 0.5, dampingFraction: 0.6)
                    .delay(delay)
                ) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

struct ShimmerEffectModifier: ViewModifier {
    let isActive: Bool

    @State private var shimmerOffset: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 100)
                        .offset(x: shimmerOffset)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 1.5)
                                .repeatForever(autoreverses: false)
                            ) {
                                shimmerOffset = geometry.size.width + 100
                            }
                        }
                    }
                }
                .mask(content)
            )
    }
}

struct GlowEffectModifier: ViewModifier {
    let glowColor: Color
    let isActive: Bool

    @State private var glowOpacity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? glowColor.opacity(glowOpacity) : .clear,
                radius: 12,
                y: 4
            )
            .onAppear {
                if isActive {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                    ) {
                        glowOpacity = 0.6
                    }
                }
            }
    }
}

struct FloatingAnimationModifier: ViewModifier {
    let offset: CGFloat
    let duration: Double

    @State private var yOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: yOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    yOffset = -offset
                }
            }
    }
}

struct PressAndHoldModifier: ViewModifier {
    let onStart: () -> Void
    let onEnd: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onStart()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onEnd()
                    }
            )
    }
}

// MARK: - Premium Button Styles

/// Breathing button style for calming actions
struct BreathingButtonStyle: ButtonStyle {
    @State private var breatheScale: CGFloat = 1.0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : breatheScale)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    breatheScale = 1.02
                }
            }
    }
}

/// Pulsing glow button for emergency/attention
struct PulsingGlowButtonStyle: ButtonStyle {
    let color: Color

    @State private var glowOpacity: Double = 0.3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: color.opacity(glowOpacity), radius: 16, y: 4)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    glowOpacity = 0.7
                }
            }
    }
}

/// Bouncy button style with spring physics
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.lightTap()
                }
            }
    }
}

// MARK: - Transition Animations

extension AnyTransition {
    /// Smooth scale and fade transition
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }

    /// Slide up with fade
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    /// Pop transition for cards
    static var pop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        )
    }

    /// Blur transition
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(blur: 10, opacity: 0),
            identity: BlurModifier(blur: 0, opacity: 1)
        )
    }
}

struct BlurModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - Interactive Springs

struct InteractiveSpring {
    /// Quick response for taps
    static let quick = Animation.spring(response: 0.25, dampingFraction: 0.7)

    /// Smooth for transitions
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Bouncy for playful interactions
    static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.5)

    /// Gentle for calming effects
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.9)

    /// Snappy for immediate feedback
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.8)
}

// MARK: - Previews

#Preview("Micro Interactions") {
    VStack(spacing: 24) {
        // Tap feedback
        Button("Tap with Feedback") {}
            .padding()
            .background(Color.appPrimary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .tapWithFeedback { print("Tapped") }

        // Bouncy button
        Button("Bouncy Button") {}
            .padding()
            .background(Color.appSecondary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .buttonStyle(BouncyButtonStyle())

        // Pulsing glow
        Button("Emergency") {}
            .padding()
            .background(Color.appDanger)
            .foregroundColor(.white)
            .cornerRadius(12)
            .buttonStyle(PulsingGlowButtonStyle(color: .appDanger))

        // Floating card
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.appCardBackground)
            .frame(height: 80)
            .shadow(radius: 4)
            .floatingAnimation()
    }
    .padding()
    .background(Color.appBackground)
}
