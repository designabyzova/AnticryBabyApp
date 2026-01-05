//
//  PremiumBadge.swift
//  BabyInCarApp
//
//  Visual indicators for content tier (Free/Premium)
//  Philosophy: Subtle, informative, never aggressive
//

import SwiftUI

// MARK: - Premium Badge
struct PremiumBadge: View {
    let accessType: FreemiumGatekeeper.TrackAccessType
    var size: BadgeSize = .regular

    enum BadgeSize {
        case small
        case regular
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .regular: return 10
            case .large: return 12
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
            case .regular: return EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .large: return EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .regular: return 10
            case .large: return 12
            }
        }
    }

    var body: some View {
        if let badge = accessType.badge {
            HStack(spacing: 3) {
                if accessType == .locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size.iconSize))
                } else if accessType == .freeRotating {
                    Image(systemName: "gift.fill")
                        .font(.system(size: size.iconSize))
                }

                Text(badge)
                    .font(.system(size: size.fontSize, weight: .bold))
            }
            .foregroundColor(foregroundColor)
            .padding(size.padding)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
        }
    }

    private var foregroundColor: Color {
        switch accessType {
        case .free: return .appSuccess
        case .freeRotating: return .white
        case .premium: return .appPrimary
        case .locked: return .white
        }
    }

    private var backgroundColor: Color {
        switch accessType {
        case .free: return .appSuccess.opacity(0.15)
        case .freeRotating: return .appSuccess
        case .premium: return .appPrimary.opacity(0.15)
        case .locked: return .appTextSecondary.opacity(0.8)
        }
    }
}

// MARK: - Track Card with Badge
struct TrackCardWithBadge: View {
    let track: AudioTrack
    let showBadge: Bool
    let onTap: () -> Void

    @StateObject private var gatekeeper = FreemiumGatekeeper.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork
                ZStack {
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
                                .overlay(
                                    Image(systemName: track.category.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(.appPrimary)
                                )
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Lock overlay for premium tracks
                    if !gatekeeper.canPlayTrack(track) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            )
                    }
                }

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(track.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.appText)
                            .lineLimit(1)

                        if showBadge {
                            PremiumBadge(
                                accessType: gatekeeper.accessType(for: track),
                                size: .small
                            )
                        }
                    }

                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Duration
                        Text(track.formattedDuration)
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)

                        // Calming score indicator
                        if track.calmingScore >= 0.85 {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                Text("Highly Calming")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.appSuccess)
                        }
                    }
                }

                Spacer()

                // Play indicator
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(gatekeeper.canPlayTrack(track) ? .appPrimary : .appTextSecondary.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Header with Free Count
struct CategoryHeaderWithFreeCount: View {
    let category: AudioCategory
    let totalTracks: Int
    let freeTracks: Int

    var body: some View {
        HStack {
            // Category icon
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appText)

                Text("\(freeTracks) free • \(totalTracks) total")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            // See all chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appTextSecondary)
        }
    }
}

// MARK: - Free Content Notice
struct FreeContentNotice: View {
    let freeTrackCount: Int
    let refreshDate: Date?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundColor(.appSuccess)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(freeTrackCount) Free Tracks This Week")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)

                if let date = refreshDate {
                    Text("Refreshes \(date, style: .relative)")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appSuccess.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appSuccess.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Upgrade Nudge Card
struct UpgradeNudgeCard: View {
    let message: String
    let ctaText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Gradient icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.appPrimary, .appSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.leading)

                    Text(ctaText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appPrimary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: .appPrimary.opacity(0.1), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
#Preview("Premium Badge - Locked") {
    VStack(spacing: 20) {
        PremiumBadge(accessType: .locked, size: .small)
        PremiumBadge(accessType: .locked, size: .regular)
        PremiumBadge(accessType: .locked, size: .large)
    }
    .padding()
}

#Preview("Premium Badge - Free Rotating") {
    VStack(spacing: 20) {
        PremiumBadge(accessType: .freeRotating, size: .small)
        PremiumBadge(accessType: .freeRotating, size: .regular)
        PremiumBadge(accessType: .freeRotating, size: .large)
    }
    .padding()
}

#Preview("Free Content Notice") {
    FreeContentNotice(
        freeTrackCount: 25,
        refreshDate: Date().addingTimeInterval(86400 * 5)
    )
    .padding()
}

#Preview("Upgrade Nudge") {
    UpgradeNudgeCard(
        message: "Unlock 47 more tracks Luna might love",
        ctaText: "See Premium",
        onTap: {}
    )
    .padding()
}
