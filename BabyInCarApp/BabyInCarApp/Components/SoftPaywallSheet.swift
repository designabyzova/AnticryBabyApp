//
//  SoftPaywallSheet.swift
//  BabyInCarApp
//
//  Gentle, non-aggressive upgrade prompts
//  Philosophy: Inform, don't block. Always provide a clear "Not Now" option.
//

import SwiftUI
import AVFoundation

// MARK: - Soft Paywall Sheet
struct SoftPaywallSheet: View {
    let track: AudioTrack
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPlayingPreview = false
    @State private var previewPlayer: AVPlayer?
    @State private var previewProgress: Double = 0

    private let previewDuration: TimeInterval = 10

    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color.appTextSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Blurred artwork with premium badge
            ZStack {
                // Artwork
                AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.3), Color.appSecondary.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .blur(radius: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appPrimary.opacity(0.3), lineWidth: 2)
                )

                // Lock icon overlay
                VStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)

                    Text("Premium")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(16)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .blur(radius: 20)
                )
            }

            // Track info
            VStack(spacing: 8) {
                Text(track.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)

                Text(track.artist)
                    .font(.system(size: 15))
                    .foregroundColor(.appTextSecondary)

                // Category badge
                HStack(spacing: 6) {
                    Image(systemName: track.category.icon)
                        .font(.system(size: 12))
                    Text(track.category.rawValue)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.appPrimary.opacity(0.1))
                )
            }

            // Preview player
            VStack(spacing: 12) {
                HStack {
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appTextSecondary)

                    Spacer()

                    Text("\(Int(previewProgress * previewDuration))s / \(Int(previewDuration))s")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appTextSecondary.opacity(0.2))

                        Capsule()
                            .fill(Color.appPrimary)
                            .frame(width: geo.size.width * previewProgress)
                    }
                }
                .frame(height: 4)

                // Play preview button
                Button {
                    togglePreview()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPlayingPreview ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))

                        Text(isPlayingPreview ? "Pause Preview" : "Play 10s Preview")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appPrimary, lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Upgrade button
                Button {
                    stopPreview()
                    onUpgrade()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))

                        Text("Unlock with Premium")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appPrimary, Color.appSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }

                // Dismiss button - always prominent and easy to tap
                Button {
                    stopPreview()
                    onDismiss()
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .onDisappear {
            stopPreview()
        }
    }

    // MARK: - Preview Playback

    private func togglePreview() {
        if isPlayingPreview {
            pausePreview()
        } else {
            playPreview()
        }
    }

    private func playPreview() {
        guard let urlString = track.streamURL, let url = URL(string: urlString) else { return }

        if previewPlayer == nil {
            previewPlayer = AVPlayer(url: url)
        }

        previewPlayer?.play()
        isPlayingPreview = true
        startProgressTimer()

        // Auto-stop after preview duration
        DispatchQueue.main.asyncAfter(deadline: .now() + previewDuration) { [self] in
            if isPlayingPreview {
                stopPreview()
            }
        }
    }

    private func pausePreview() {
        previewPlayer?.pause()
        isPlayingPreview = false
    }

    private func stopPreview() {
        previewPlayer?.pause()
        previewPlayer = nil
        isPlayingPreview = false
        previewProgress = 0
    }

    private func startProgressTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isPlayingPreview {
                timer.invalidate()
                return
            }

            guard let player = previewPlayer,
                  let currentTime = player.currentItem?.currentTime().seconds,
                  currentTime.isFinite else { return }

            previewProgress = min(currentTime / previewDuration, 1.0)

            if previewProgress >= 1.0 {
                timer.invalidate()
                stopPreview()
            }
        }
    }
}

// MARK: - Engagement Upgrade Sheet
struct EngagementUpgradeSheet: View {
    let prompt: EngagementTriggerService.UpgradePrompt
    let babyName: String?
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color.appTextSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer()

            // Icon based on style
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: iconName)
                    .font(.system(size: 44))
                    .foregroundColor(accentColor)
            }

            // Title
            Text(personalizedTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)

            // Message
            Text(prompt.message)
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    onUpgrade()
                    dismiss()
                } label: {
                    Text(prompt.ctaText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(accentColor)
                        )
                }

                Button {
                    onDismiss()
                    dismiss()
                } label: {
                    Text(prompt.dismissText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .overlay(
            // Confetti overlay for celebration style
            Group {
                if prompt.style == .celebration && showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
        )
        .onAppear {
            if prompt.style == .celebration {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showConfetti = true
                }
            }
        }
    }

    private var personalizedTitle: String {
        if let name = babyName {
            return prompt.title.replacingOccurrences(of: "your baby", with: name)
        }
        return prompt.title
    }

    private var accentColor: Color {
        switch prompt.style {
        case .positive: return .appSuccess
        case .gentle: return .appPrimary
        case .urgent: return .appWarning
        case .celebration: return .appPrimary
        }
    }

    private var iconName: String {
        switch prompt.style {
        case .positive: return "heart.fill"
        case .gentle: return "star.fill"
        case .urgent: return "clock.fill"
        case .celebration: return "party.popper.fill"
        }
    }
}

// MARK: - Confetti View (Simple)
struct ConfettiView: View {
    @State private var particles: [(offset: CGSize, rotation: Double, color: Color)] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { i in
                if i < particles.count {
                    Circle()
                        .fill(particles[i].color)
                        .frame(width: 8, height: 8)
                        .offset(particles[i].offset)
                        .rotationEffect(.degrees(particles[i].rotation))
                }
            }
        }
        .onAppear {
            generateParticles()
            animateParticles()
        }
    }

    private func generateParticles() {
        let colors: [Color] = [.appPrimary, .appSecondary, .appSuccess, .yellow, .pink]
        particles = (0..<30).map { _ in
            (
                offset: CGSize(width: CGFloat.random(in: -150...150), height: -200),
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .appPrimary
            )
        }
    }

    private func animateParticles() {
        withAnimation(.easeOut(duration: 2.0)) {
            particles = particles.map { particle in
                (
                    offset: CGSize(
                        width: particle.offset.width + CGFloat.random(in: -50...50),
                        height: 400
                    ),
                    rotation: particle.rotation + Double.random(in: 180...720),
                    color: particle.color
                )
            }
        }
    }
}

// MARK: - Trial Banner
struct TrialBanner: View {
    @ObservedObject var trialManager = TrialManager.shared
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let viewModel = trialManager.bannerViewModel

        if viewModel.isVisible {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconForUrgency(viewModel.urgency))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                // Message
                Text(viewModel.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                // Action button
                Button(action: onTap) {
                    Text(viewModel.actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(backgroundColor(for: viewModel.urgency))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor(for: viewModel.urgency))
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func iconForUrgency(_ urgency: TrialManager.TrialBannerViewModel.Urgency) -> String {
        switch urgency {
        case .low: return "star.fill"
        case .medium: return "clock.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .expired: return "arrow.up.circle.fill"
        }
    }

    private func backgroundColor(for urgency: TrialManager.TrialBannerViewModel.Urgency) -> Color {
        switch urgency {
        case .low: return .appPrimary
        case .medium: return .orange
        case .high: return .appDanger
        case .expired: return .appTextSecondary
        }
    }
}

// MARK: - Preview
#Preview("Soft Paywall") {
    SoftPaywallSheet(
        track: AudioTrack(
            title: "Moonlight Sonata",
            artist: "Beethoven",
            category: .classicalMusic,
            duration: 300,
            isPremium: true,
            audioSourceType: .streamed
        ),
        onUpgrade: {},
        onDismiss: {}
    )
}

#Preview("Engagement Prompt") {
    EngagementUpgradeSheet(
        prompt: EngagementTriggerService.UpgradePrompt(
            title: "Your baby loves this!",
            message: "Get more tracks like the ones that work",
            ctaText: "Unlock More",
            style: .positive
        ),
        babyName: "Luna",
        onUpgrade: {},
        onDismiss: {}
    )
}
