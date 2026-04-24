//
//  BeeEmptyState.swift
//  BabyInCarApp
//
//  Reusable empty-state view with a bee-in-hexagon illustration.
//  Uses SF Symbols composited in SwiftUI (no raster assets) to stay lightweight.
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
        VStack(spacing: 20) {
            BeeIcon(mood: mood)
                .frame(width: 140, height: 140)

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
    }
}

// MARK: - Bee Icon (SF Symbols composite)

private struct BeeIcon: View {
    let mood: BeeEmptyState.Mood

    var body: some View {
        ZStack {
            // Hexagon cell — honey background
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.clear)
            HexShape()
                .fill(
                    LinearGradient(
                        colors: [Color.appPrimaryLight, Color.appPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    HexShape().stroke(Color.honeyDeep.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.appPrimary.opacity(0.25), radius: 10, x: 0, y: 4)

            // Bee body — rounded pill with two stripes
            BeeBody()
                .frame(width: 58, height: 36)
                .offset(y: mood == .sleeping ? 6 : 0)

            // Mood overlay
            moodOverlay
                .offset(overlayOffset)
        }
    }

    @ViewBuilder
    private var moodOverlay: some View {
        switch mood {
        case .sleeping:
            // "Zzz" in soft charcoal
            Text("Zzz")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.hiveCharcoal.opacity(0.75))
                .rotationEffect(.degrees(-14))
        case .listening:
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.hiveCharcoal.opacity(0.8))
        case .happy:
            Image(systemName: "heart.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appTertiary)
        }
    }

    private var overlayOffset: CGSize {
        switch mood {
        case .sleeping:  return CGSize(width: 36, height: -34)
        case .listening: return CGSize(width: 0, height: -46)
        case .happy:     return CGSize(width: 30, height: -40)
        }
    }
}

/// Minimal stylized bee — oval body + two charcoal stripes + wing arc.
private struct BeeBody: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.appPrimaryLight)
                .overlay(
                    Capsule().stroke(Color.honeyDeep.opacity(0.7), lineWidth: 1.5)
                )

            // Two stripes clipped to capsule
            HStack(spacing: 8) {
                Spacer()
                Rectangle().fill(Color.hiveCharcoal).frame(width: 6)
                Spacer().frame(width: 4)
                Rectangle().fill(Color.hiveCharcoal).frame(width: 6)
                Spacer()
            }
            .clipShape(Capsule())

            // Wing — translucent ellipse top-right
            Ellipse()
                .fill(Color.white.opacity(0.6))
                .overlay(Ellipse().stroke(Color.honeyDeep.opacity(0.5), lineWidth: 1))
                .frame(width: 22, height: 16)
                .offset(x: 4, y: -10)
        }
    }
}

/// Pointy-top regular hexagon path (shared local copy — small enough not to warrant extraction).
private struct HexShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) / 2
        let cx = rect.midX
        let cy = rect.midY
        for i in 0..<6 {
            let angle = (CGFloat.pi / 3) * CGFloat(i) - .pi / 2
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
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
