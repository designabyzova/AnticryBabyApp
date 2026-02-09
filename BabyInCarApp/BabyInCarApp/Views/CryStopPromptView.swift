//
//  CryStopPromptView.swift
//  BabyInCarApp
//
//  Prompt shown when auto-detection finds baby stopped crying
//  "Baby seems calmer! Did the music help?"
//

import SwiftUI

struct CryStopPromptView: View {

    @StateObject private var autoDetector = CryStopAutoDetector.shared
    @Environment(\.colorScheme) private var colorScheme

    var onConfirm: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Success indicator
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
                    .opacity(0.9)
            }
            .padding(.top, 8)

            // Title
            Text("Baby seems calmer!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // Subtitle
            Text("Did the music help?")
                .font(.body)
                .foregroundColor(.secondary)

            // Action buttons
            HStack(spacing: 16) {
                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Still Crying")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                        )
                }

                // Confirm button
                Button {
                    onConfirm()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("It Helped!")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Overlay Modifier

/// Modifier to show cry stop prompt as an overlay
struct CryStopPromptOverlay: ViewModifier {

    @StateObject private var autoDetector = CryStopAutoDetector.shared
    @State private var isShowing: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowing {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    CryStopPromptView(
                        onConfirm: {
                            withAnimation(.spring(response: 0.3)) {
                                isShowing = false
                            }
                            autoDetector.confirmHelped()
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.3)) {
                                isShowing = false
                            }
                            autoDetector.dismissPrompt()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onReceive(autoDetector.$shouldShowPrompt) { shouldShow in
                withAnimation(.spring(response: 0.4)) {
                    isShowing = shouldShow
                }
            }
    }
}

extension View {
    /// Add cry stop prompt overlay to any view
    func withCryStopPrompt() -> some View {
        modifier(CryStopPromptOverlay())
    }
}

// MARK: - Progress Indicator

/// Shows progress toward cry stop detection (optional, for debugging/premium)
struct CryStopProgressView: View {

    @StateObject private var autoDetector = CryStopAutoDetector.shared

    var body: some View {
        if autoDetector.isInQuietPeriod && !autoDetector.shouldShowPrompt {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text("Detecting if baby calmed down...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: autoDetector.quietPeriodProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Preview

#Preview("Cry Stop Prompt") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack {
            Text("Background Content")
                .foregroundColor(.secondary)
        }

        CryStopPromptView(
            onConfirm: { print("Confirmed!") },
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview("Progress View") {
    VStack {
        CryStopProgressView()
    }
    .padding()
}
