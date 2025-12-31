//
//  Cards.swift
//  BabyInCarApp
//
//  Premium card components with neumorphic effects and smooth animations
//

import SwiftUI

// MARK: - Neumorphic Card

/// Soft neumorphic card with subtle depth
struct NeuCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = DesignTokens.radiusL
    var padding: CGFloat = DesignTokens.spacingM

    init(cornerRadius: CGFloat = DesignTokens.radiusL, padding: CGFloat = DesignTokens.spacingM, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appCardBackground)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: -2, y: -2)
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 3, y: 3)
            )
    }
}

// MARK: - Elevated Card

/// Card with pronounced shadow for modals and overlays
struct ElevatedCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = DesignTokens.radiusXL
    var padding: CGFloat = DesignTokens.spacingL

    init(cornerRadius: CGFloat = DesignTokens.radiusXL, padding: CGFloat = DesignTokens.spacingL, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appSurface)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            )
    }
}

// MARK: - Glass Card (Frosted Effect)

/// Frosted glass effect for overlays
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = DesignTokens.radiusL
    var padding: CGFloat = DesignTokens.spacingM

    init(cornerRadius: CGFloat = DesignTokens.radiusL, padding: CGFloat = DesignTokens.spacingM, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Category Card

/// Beautiful category selection card with gradient background
struct CategoryCardView: View {
    let category: AudioCategory
    var isSelected: Bool = false
    var showTrackCount: Bool = true
    var trackCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.forCategory(category).opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: category.icon)
                    .font(.system(size: 22))
                    .foregroundColor(Color.forCategory(category))
            }

            Spacer()

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.appSubheadlineMedium)
                    .foregroundColor(.appText)
                    .lineLimit(1)

                if showTrackCount && trackCount > 0 {
                    Text("\(trackCount) tracks")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                .fill(Color.appCardBackground)
                .shadow(
                    color: .black.opacity(isSelected ? 0.12 : 0.06),
                    radius: isSelected ? 12 : 6,
                    y: isSelected ? 6 : 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                .stroke(isSelected ? Color.forCategory(category) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Track Card

/// Card for displaying audio tracks
struct TrackCardView: View {
    let track: AudioTrack
    var isPlaying: Bool = false
    var showFavorite: Bool = true
    var isFavorite: Bool = false
    var onFavoriteToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Album art / category icon
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.radiusS)
                    .fill(Color.forCategory(track.category).opacity(0.15))
                    .frame(width: 56, height: 56)

                if isPlaying {
                    EqualizerAnimation()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: track.category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color.forCategory(track.category))
                }
            }

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.appBodyMedium)
                    .foregroundColor(isPlaying ? .appPrimary : .appText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(track.artist)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)

                    if let language = track.language {
                        Text(language.flag)
                            .font(.appCaption)
                    }

                    Text("•")
                        .foregroundColor(.appTextTertiary)

                    Text(track.formattedDuration)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                .lineLimit(1)
            }

            Spacer()

            // Favorite button
            if showFavorite {
                Button {
                    onFavoriteToggle?()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isFavorite ? .appTertiary : .appTextTertiary)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

// MARK: - Quick Pick Card

/// Compact card for quick picks grid
struct QuickPickCardView: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String?

    var body: some View {
        VStack(spacing: DesignTokens.spacingS) {
            // Icon circle
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                    .fill(color.opacity(0.15))
                    .frame(height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
            }

            // Title
            VStack(spacing: 2) {
                Text(title)
                    .font(.appCaptionMedium)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.appCaption2)
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Hero Card

/// Large hero card for featured content
struct HeroCard<Content: View>: View {
    let content: Content
    var backgroundGradient: LinearGradient = .dreamyGradient
    var height: CGFloat = 200

    init(
        backgroundGradient: LinearGradient = .dreamyGradient,
        height: CGFloat = 200,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundGradient = backgroundGradient
        self.height = height
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusXL)
                    .fill(backgroundGradient)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, y: 8)
    }
}

// MARK: - Equalizer Animation

/// Animated equalizer bars for "now playing" indicator
struct EqualizerAnimation: View {
    @State private var heights: [CGFloat] = [0.3, 0.5, 0.7, 0.4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.appPrimary)
                    .frame(width: 4, height: 24 * heights[index])
            }
        }
        .onAppear {
            animate()
        }
    }

    private func animate() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            heights = [0.7, 0.4, 0.5, 0.8]
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                heights = [0.5, 0.8, 0.3, 0.6]
            }
        }
    }
}

// MARK: - Preview

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 24) {
            // Neumorphic
            NeuCard {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.appPrimary)
                    Text("Sleep Mode Active")
                        .font(.appHeadline)
                    Spacer()
                }
            }

            // Elevated
            ElevatedCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Premium Feature")
                        .font(.appTitle3)
                    Text("Unlock all sounds and features")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                }
            }

            // Glass
            ZStack {
                Color.appPrimary.opacity(0.3)
                    .frame(height: 150)
                    .cornerRadius(20)

                GlassCard {
                    Text("Frosted Glass Effect")
                        .font(.appHeadline)
                }
                .padding()
            }

            // Category cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CategoryCardView(category: .classicalMusic, trackCount: 24)
                CategoryCardView(category: .natureSounds, isSelected: true, trackCount: 18)
            }

            // Track card
            TrackCardView(
                track: AudioTrack(
                    id: UUID(),
                    title: "Gentle Lullaby",
                    artist: "Sleep Sounds",
                    category: .classicalMusic,
                    language: .english,
                    duration: 180,
                    audioSourceType: .bundled
                ),
                isPlaying: true,
                isFavorite: true
            )

            // Quick picks
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickPickCardView(title: "Lullabies", icon: "moon.stars.fill", color: .classicalColor)
                QuickPickCardView(title: "Rain Sounds", icon: "cloud.rain.fill", color: .natureColor)
                QuickPickCardView(title: "White Noise", icon: "waveform", color: .whiteNoiseColor)
            }
        }
        .padding()
    }
    .background(Color.appBackground)
}
