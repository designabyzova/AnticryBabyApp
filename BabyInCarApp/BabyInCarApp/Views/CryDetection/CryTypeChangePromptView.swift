//
//  CryTypeChangePromptView.swift
//  BabyInCarApp
//
//  Prompt shown when cry type change is detected during playback
//  "Cry pattern may have changed to [tired]. Change playlist?"
//

import SwiftUI

// MARK: - CryTypeChangePromptView

/// Prompt view for cry type change detection
struct CryTypeChangePromptView: View {

    let currentType: CryType
    let newType: CryType
    let confidence: Double

    var onAccept: () -> Void
    var onReject: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // Change indicator
            HStack(spacing: 16) {
                // Current type
                cryTypeIcon(currentType, isActive: false)

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.secondary)

                // New type
                cryTypeIcon(newType, isActive: true)
            }
            .padding(.top, 8)

            // Title
            VStack(spacing: 8) {
                Text("Cry Pattern Changed")
                    .font(.title3.bold())
                    .foregroundColor(.primary)

                Text("Baby may now be \(newType.displayName.lowercased())")
                    .font(.body)
                    .foregroundColor(.secondary)

                // Confidence badge
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption)
                    Text("\(Int(confidence * 100))% confidence")
                        .font(.caption.bold())
                }
                .foregroundColor(colorForCryType(newType))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(colorForCryType(newType).opacity(0.15))
                )
            }

            // Suggestion
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(newType.suggestedAction)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )

            // Action buttons
            VStack(spacing: 12) {
                // Accept - switch playlist
                Button {
                    onAccept()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.swap")
                        Text("Switch Playlist")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colorForCryType(newType))
                    )
                }

                // Reject - keep current
                Button {
                    onReject()
                } label: {
                    Text("Keep Current Playlist")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Components

    private func cryTypeIcon(_ type: CryType, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(colorForCryType(type).opacity(isActive ? 0.2 : 0.1))
                    .frame(width: 56, height: 56)

                if isActive {
                    Circle()
                        .stroke(colorForCryType(type), lineWidth: 2)
                        .frame(width: 56, height: 56)
                }

                Image(systemName: type.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(colorForCryType(type).opacity(isActive ? 1.0 : 0.5))
            }

            Text(type.displayName)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }

    private func colorForCryType(_ type: CryType) -> Color {
        switch type {
        case .hunger: return .orange
        case .tired: return .purple
        case .pain: return .red
        case .attention: return .blue
        case .discomfort: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Overlay Modifier

/// Modifier to show cry type change prompt as an overlay
struct CryTypeChangePromptOverlay: ViewModifier {

    @ObservedObject private var changeDetector = CryTypeChangeDetector.shared
    @State private var isShowing: Bool = false
    @State private var detectedNewType: CryType = .unknown
    @State private var detectedConfidence: Double = 0.0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowing {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    CryTypeChangePromptView(
                        currentType: changeDetector.currentCryType,
                        newType: detectedNewType,
                        confidence: detectedConfidence,
                        onAccept: {
                            withAnimation(.spring(response: 0.3)) {
                                isShowing = false
                            }
                            changeDetector.acceptChange()
                        },
                        onReject: {
                            withAnimation(.spring(response: 0.3)) {
                                isShowing = false
                            }
                            changeDetector.rejectChange()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onReceive(changeDetector.$shouldShowChangePrompt) { shouldShow in
                if shouldShow, let newType = changeDetector.potentialNewType {
                    detectedNewType = newType
                    detectedConfidence = changeDetector.confirmedAgreement
                    withAnimation(.spring(response: 0.4)) {
                        isShowing = true
                    }
                } else if !shouldShow {
                    withAnimation(.spring(response: 0.3)) {
                        isShowing = false
                    }
                }
            }
    }
}

extension View {
    /// Add cry type change prompt overlay to any view
    func withCryTypeChangePrompt() -> some View {
        modifier(CryTypeChangePromptOverlay())
    }
}

// MARK: - Change Progress Indicator

/// Shows progress toward cry type change detection (optional)
struct CryTypeChangeProgressView: View {

    @ObservedObject private var changeDetector = CryTypeChangeDetector.shared

    var body: some View {
        if let newType = changeDetector.potentialNewType,
           changeDetector.changeProgress > 0,
           !changeDetector.shouldShowChangePrompt {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.orange)

                Text("Detecting: \(newType.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(changeDetector.changeProgress * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Preview

#Preview("Change Prompt") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        CryTypeChangePromptView(
            currentType: .hunger,
            newType: .tired,
            confidence: 0.82,
            onAccept: { print("Accepted") },
            onReject: { print("Rejected") }
        )
    }
}

#Preview("Change Progress") {
    VStack {
        CryTypeChangeProgressView()
    }
    .padding()
}
