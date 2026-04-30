//
//  BeeEmptyState.swift
//  BabyInCarApp
//
//  Reusable empty-state view built around the Soothbee brand mark.
//  The illustration mirrors the website/App Icon logo (cartoon bee + baby)
//  set inside a soft honey-to-lavender glow, with a small mood badge.
//

import SwiftUI

struct BeeEmptyState: View {
    enum Mood {
        /// Sleeping bee — use for Favorites (nothing collected yet).
        case sleeping
        /// Listening bee — use for Queue/Smart screens (nothing playing).
        case listening
        /// Happy bee — use for Playlists (invite creation).
        case happy
    }

    let mood: Mood
    let title: String
    let caption: String

    var body: some View {
        VStack(spacing: 22) {
            BrandBeeMark(mood: mood)
                .frame(width: 164, height: 164)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)

                Text(caption)
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(caption)"))
    }
}

// MARK: - Brand Mark (logo + mood badge)

private struct BrandBeeMark: View {
    let mood: BeeEmptyState.Mood

    var body: some View {
        ZStack {
            // Soft honey→lavender glow behind the logo — echoes the website hero.
            RadialGradient(
                colors: [
                    Color.appPrimary.opacity(0.28),
                    Color.appSecondary.opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 100
            )
            .blur(radius: 4)

            // Honeycomb halo — 6 tiny hexagons orbiting the mark.
            HoneycombHalo()
                .stroke(Color.honeyDeep.opacity(0.18), lineWidth: 1.2)

            // The Soothbee brand logo (same asset as About screen / website).
            Image("BrandLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.appPrimary.opacity(0.28), radius: 14, x: 0, y: 8)

            // Mood badge pinned to the top-trailing corner of the logo.
            MoodBadge(mood: mood)
                .offset(x: 56, y: -56)
        }
    }
}

// MARK: - Mood badge

private struct MoodBadge: View {
    let mood: BeeEmptyState.Mood

    var body: some View {
        ZStack {
            Circle()
                .fill(badgeFill)
                .frame(width: 40, height: 40)
                .shadow(color: badgeShadow, radius: 6, x: 0, y: 3)

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: 40, height: 40)

            icon
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch mood {
        case .sleeping:
            Text("Zzz")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.hiveCharcoal)
                .rotationEffect(.degrees(-12))
        case .listening:
            Image(systemName: "waveform")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.hiveCharcoal)
        case .happy:
            Image(systemName: "heart.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var badgeFill: Color {
        switch mood {
        case .sleeping:  return Color.appPrimaryLight
        case .listening: return Color.appPrimaryLight
        case .happy:     return Color.appTertiary
        }
    }

    private var badgeShadow: Color {
        switch mood {
        case .happy:     return Color.appTertiary.opacity(0.35)
        default:         return Color.appPrimary.opacity(0.35)
        }
    }
}

// MARK: - Honeycomb halo (decorative, non-interactive)

/// Six pointy-top hexagons arranged in a circle around the centre,
/// used purely as a decorative stroke behind the brand mark.
private struct HoneycombHalo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let orbit = min(rect.width, rect.height) / 2 - 8
        let hexRadius: CGFloat = 9

        for i in 0..<6 {
            let angle = (CGFloat.pi / 3) * CGFloat(i) - .pi / 2
            let hx = cx + orbit * cos(angle)
            let hy = cy + orbit * sin(angle)
            appendHex(to: &path, center: CGPoint(x: hx, y: hy), radius: hexRadius)
        }
        return path
    }

    private func appendHex(to path: inout Path, center: CGPoint, radius: CGFloat) {
        for i in 0..<6 {
            let angle = (CGFloat.pi / 3) * CGFloat(i) - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
    }
}

// MARK: - Shared decorative types (exposed for Detect + Profile screens)
//
// `HoneycombPattern` itself is defined once in HoneyDropAnimation.swift
// (with `cellSize:` parameter). The two helpers below wrap it for brand use.

/// Full-screen honeycomb backdrop. Drop behind a ScrollView when a gradient
/// alone feels flat and you want a brand hint in negative space.
struct HoneycombBackdrop: View {
    var tile: CGFloat = 44
    var strokeColor: Color = Color.appPrimary.opacity(0.10)
    var lineWidth: CGFloat = 1

    var body: some View {
        HoneycombPattern(cellSize: tile)
            .stroke(strokeColor, lineWidth: lineWidth)
            .allowsHitTesting(false)
    }
}

/// Small bee mark that reuses the brand asset at a decorative scale.
/// Optional rotation adds a "hovering" feel when placed near content.
struct BrandBeeMini: View {
    var size: CGFloat = 44
    var rotation: Double = -8

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .rotationEffect(.degrees(rotation))
            .shadow(color: Color.appPrimary.opacity(0.28), radius: 6, x: 0, y: 3)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("All moods") {
    VStack(spacing: 32) {
        BeeEmptyState(
            mood: .sleeping,
            title: "No favorites yet",
            caption: "Tap the heart on a track to keep the ones your baby loves."
        )
        BeeEmptyState(
            mood: .listening,
            title: "Your hive is quiet",
            caption: "The bee is ready to listen when you're ready to play."
        )
        BeeEmptyState(
            mood: .happy,
            title: "Build your first playlist",
            caption: "Collect a calm mix for bedtime, naps, or the car."
        )
    }
    .background(Color.appBackground)
}
