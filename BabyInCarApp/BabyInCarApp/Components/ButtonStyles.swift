//
//  ButtonStyles.swift
//  BabyInCarApp
//
//  Premium button styles with animations, haptics, and visual feedback
//  Designed for accessibility and delightful micro-interactions
//

import SwiftUI
import UIKit

// MARK: - Primary Button Style

/// Main call-to-action button with scale animation and haptic feedback
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                ZStack {
                    // Background with gradient
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(isEnabled ? Color.appPrimary : Color.appPrimary.opacity(0.5))

                    // Subtle shine overlay
                    if isEnabled && !configuration.isPressed {
                        RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
            )
            .shadow(
                color: isEnabled ? Color.appPrimary.opacity(0.3) : .clear,
                radius: configuration.isPressed ? 4 : 8,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - Secondary Button Style

/// Outlined/ghost button with subtle background on press
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(isEnabled ? .appPrimary : .appTextSecondary)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                    .fill(configuration.isPressed ? Color.appPrimary.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                    .stroke(isEnabled ? Color.appPrimary : Color.appTextSecondary.opacity(0.5), lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// MARK: - Soft Button Style

/// Soft background button for less prominent actions
struct SoftButtonStyle: ButtonStyle {
    var color: Color = .appPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButtonSmall)
            .foregroundColor(color)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusS)
                    .fill(color.opacity(configuration.isPressed ? 0.2 : 0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

/// Circular icon button with glow effect on press
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var backgroundColor: Color = .appCardBackground
    var foregroundColor: Color = .appText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.5))
            .foregroundColor(foregroundColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .shadow(
                        color: .black.opacity(configuration.isPressed ? 0.03 : 0.08),
                        radius: configuration.isPressed ? 2 : 4,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// MARK: - Emergency Button Style

/// Attention-grabbing button with pulsing glow effect
struct EmergencyButtonStyle: ButtonStyle {
    @State private var isPulsing = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Pulsing glow
                    RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                        .fill(Color.emergencyGlow.opacity(0.5))
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .opacity(isPulsing ? 0.5 : 0.3)
                        .blur(radius: 10)

                    // Main background
                    RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                        .fill(
                            LinearGradient(
                                colors: [Color.appWarning, Color.appDanger],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Shine
                    RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
    }
}

// MARK: - Pill Button Style

/// Capsule-shaped button for tags and filters
struct PillButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var selectedColor: Color = .appPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appCaptionMedium)
            .foregroundColor(isSelected ? .white : .appTextSecondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(isSelected ? selectedColor : Color.appCardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.appTextTertiary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }
}

// MARK: - Card Press Style

/// Style for pressable cards with subtle depth change
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.04 : 0.08),
                radius: configuration.isPressed ? 4 : 8,
                y: configuration.isPressed ? 2 : 4
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Bouncy Button Style

/// Fun bouncy effect for playful interactions
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
    }
}

// MARK: - Scale Button Style

/// Simple scale effect for interactive elements
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Floating Action Button

/// Large floating action button for primary actions
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var color: Color = .appPrimary
    var size: CGFloat = 56

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Shadow circle
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 8)
                    .offset(y: 4)

                // Main button
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.25)) {
                        isPressed = true
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Play/Pause Button

/// Large animated play/pause button for player
struct PlayPauseButton: View {
    @Binding var isPlaying: Bool
    var size: CGFloat = 72
    var color: Color = .appPrimary
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Outer glow when playing
                if isPlaying {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: size + 12, height: size + 12)
                        .blur(radius: 10)
                }

                // Main circle
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.4), radius: 10, y: 4)

                // Icon with morph animation
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(x: isPlaying ? 0 : 2) // Play icon visual centering
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    ScrollView {
        VStack(spacing: 24) {
            // Primary
            Button("Get Started") {}
                .buttonStyle(PrimaryButtonStyle())

            // Secondary
            Button("Learn More") {}
                .buttonStyle(SecondaryButtonStyle())

            // Soft
            HStack {
                Button("Filter") {}
                    .buttonStyle(SoftButtonStyle())

                Button("Sort") {}
                    .buttonStyle(SoftButtonStyle(color: .appSecondary))
            }

            // Emergency
            Button {
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("EMERGENCY CRY-STOP")
                }
            }
            .buttonStyle(EmergencyButtonStyle())

            // Icon buttons
            HStack(spacing: 16) {
                Button {} label: {
                    Image(systemName: "heart")
                }
                .buttonStyle(IconButtonStyle())

                Button {} label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(IconButtonStyle())

                Button {} label: {
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(IconButtonStyle(backgroundColor: .appPrimary.opacity(0.1), foregroundColor: .appPrimary))
            }

            // Pills
            HStack {
                Button("All") {}
                    .buttonStyle(PillButtonStyle(isSelected: true))

                Button("Lullabies") {}
                    .buttonStyle(PillButtonStyle())

                Button("Nature") {}
                    .buttonStyle(PillButtonStyle())
            }

            // FAB
            HStack {
                Spacer()
                FloatingActionButton(icon: "plus") {}
            }

            // Play/Pause
            PlayPauseButton(isPlaying: .constant(false), color: .classicalColor) {}

            PlayPauseButton(isPlaying: .constant(true), color: .whiteNoiseColor) {}
        }
        .padding()
    }
    .background(Color.appBackground)
}
