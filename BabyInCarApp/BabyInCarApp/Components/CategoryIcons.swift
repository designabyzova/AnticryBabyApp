//
//  CategoryIcons.swift
//  BabyInCarApp
//
//  Custom themed category icons for the audio library
//

import SwiftUI

// MARK: - Category Icon Type

enum CategoryIconType: String, CaseIterable {
    case classical = "Classical Music"
    case fairyTales = "Fairy Tales"
    case whiteNoise = "White Noise"
    case natureSounds = "Nature Sounds"
    case instrumental = "Instrumental"
    case childrensSongs = "Children's Songs"
    case podcasts = "Podcasts"
    case lullabies = "Lullabies"
    case ambient = "Ambient"
    case meditation = "Meditation"

    var iconColor: Color {
        switch self {
        case .classical: return Color.appPrimary
        case .fairyTales: return Color(hex: "E8B4D4") // Soft pink
        case .whiteNoise: return Color.appSecondary
        case .natureSounds: return Color.appAccentMint
        case .instrumental: return Color(hex: "F4D03F") // Golden
        case .childrensSongs: return Color.appAccentCoral
        case .podcasts: return Color(hex: "A78BFA") // Purple
        case .lullabies: return Color.appPrimary
        case .ambient: return Color.appSecondary
        case .meditation: return Color.appAccentMint
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .classical: return [Color.appPrimary, Color.appPrimary.opacity(0.6)]
        case .fairyTales: return [Color(hex: "E8B4D4"), Color(hex: "DDA0DD")]
        case .whiteNoise: return [Color.appSecondary, Color.appSecondary.opacity(0.6)]
        case .natureSounds: return [Color.appAccentMint, Color(hex: "98D8AA")]
        case .instrumental: return [Color(hex: "F4D03F"), Color(hex: "F5CBA7")]
        case .childrensSongs: return [Color.appAccentCoral, Color.appAccentCoral.opacity(0.7)]
        case .podcasts: return [Color(hex: "A78BFA"), Color(hex: "C4B5FD")]
        case .lullabies: return [Color.appPrimary, Color.appSecondary.opacity(0.7)]
        case .ambient: return [Color.appSecondary, Color.appAccentMint.opacity(0.7)]
        case .meditation: return [Color.appAccentMint, Color.appPrimary.opacity(0.5)]
        }
    }
}

// MARK: - Category Icon View

/// Custom animated category icon
struct CategoryIconView: View {
    let type: CategoryIconType
    var size: CGFloat = 48
    var animated: Bool = true

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: type.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: type.iconColor.opacity(0.3), radius: 6, x: 0, y: 3)

            // Icon content
            iconContent
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch type {
        case .classical:
            ClassicalMusicIcon(isAnimating: isAnimating)
        case .fairyTales:
            FairyTalesIcon(isAnimating: isAnimating)
        case .whiteNoise:
            WhiteNoiseIcon(isAnimating: isAnimating)
        case .natureSounds:
            NatureSoundsIcon(isAnimating: isAnimating)
        case .instrumental:
            InstrumentalIcon(isAnimating: isAnimating)
        case .childrensSongs:
            ChildrensSongsIcon(isAnimating: isAnimating)
        case .podcasts:
            PodcastsIcon(isAnimating: isAnimating)
        case .lullabies:
            LullabiesIcon(isAnimating: isAnimating)
        case .ambient:
            AmbientIcon(isAnimating: isAnimating)
        case .meditation:
            MeditationIcon(isAnimating: isAnimating)
        }
    }
}

// MARK: - Classical Music Icon (Piano Keys + Treble Clef)

struct ClassicalMusicIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Piano keys
            HStack(spacing: 1) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index % 2 == 0 ? Color.white : Color.white.opacity(0.7))
                        .frame(width: 5, height: index % 2 == 0 ? 16 : 12)
                }
            }
            .offset(y: 4)

            // Treble clef symbol
            Text("\u{1D11E}")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .offset(y: -6)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
        }
    }
}

// MARK: - Fairy Tales Icon (Book with Stars)

struct FairyTalesIcon: View {
    var isAnimating: Bool

    @State private var starScale: [CGFloat] = [1.0, 1.0, 1.0]

    var body: some View {
        ZStack {
            // Open book
            BookShape()
                .fill(Color.white)
                .frame(width: 22, height: 16)

            // Stars floating above
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 5 + CGFloat(index)))
                    .foregroundColor(.white.opacity(0.9))
                    .offset(
                        x: CGFloat([-6, 6, 0][index]),
                        y: CGFloat([-8, -10, -14][index])
                    )
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
        }
    }
}

struct BookShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Left page
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h * 0.1))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))

        // Right page
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.1))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))

        // Spine
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))

        return path
    }
}

// MARK: - White Noise Icon (Soft Waves)

struct WhiteNoiseIcon: View {
    var isAnimating: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                WaveBar(delay: Double(index) * 0.1, isAnimating: isAnimating)
            }
        }
    }
}

struct WaveBar: View {
    var delay: Double
    var isAnimating: Bool

    @State private var height: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(delay)) {
                    height = CGFloat.random(in: 12...20)
                }
            }
    }
}

// MARK: - Nature Sounds Icon (Leaf + Cloud)

struct NatureSoundsIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Cloud
            CloudIconShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: 20, height: 12)
                .offset(x: 4, y: -6)
                .scaleEffect(isAnimating ? 1.05 : 1.0)

            // Leaf
            LeafShape()
                .fill(Color.white)
                .frame(width: 16, height: 18)
                .rotationEffect(.degrees(-15))
                .offset(x: -3, y: 3)
        }
    }
}

struct CloudIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.addEllipse(in: CGRect(x: 0, y: h * 0.4, width: w * 0.4, height: h * 0.6))
        path.addEllipse(in: CGRect(x: w * 0.6, y: h * 0.4, width: w * 0.4, height: h * 0.6))
        path.addEllipse(in: CGRect(x: w * 0.2, y: 0, width: w * 0.6, height: h * 0.8))

        return path
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control: CGPoint(x: w, y: h * 0.3)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control: CGPoint(x: 0, y: h * 0.3)
        )

        // Leaf vein
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))

        return path
    }
}

// MARK: - Instrumental Icon (Harp + Bells)

struct InstrumentalIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Harp frame
            HarpShape()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 20, height: 22)

            // Harp strings
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 1, height: 12 - CGFloat(index))
                }
            }
            .offset(x: 1, y: 2)

            // Bell
            Image(systemName: "bell.fill")
                .font(.system(size: 8))
                .foregroundColor(.white)
                .offset(x: 8, y: -8)
                .scaleEffect(isAnimating ? 1.15 : 1.0)
        }
    }
}

struct HarpShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Curved frame
        path.move(to: CGPoint(x: 0, y: h))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.8, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w * 0.3, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Children's Songs Icon (Music Box)

struct ChildrensSongsIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Music box body
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: 20, height: 14)
                .offset(y: 4)

            // Music box lid (open)
            MusicBoxLid()
                .fill(Color.white.opacity(0.9))
                .frame(width: 22, height: 10)
                .offset(y: -5)
                .rotationEffect(.degrees(isAnimating ? -5 : 0), anchor: .bottom)

            // Musical note coming out
            Image(systemName: "music.note")
                .font(.system(size: 10))
                .foregroundColor(.white)
                .offset(x: 8, y: -10)
                .opacity(isAnimating ? 1.0 : 0.6)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
    }
}

struct MusicBoxLid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.1, y: 0))
        path.addLine(to: CGPoint(x: w * 0.9, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Podcasts Icon (Microphone + Hearts)

struct PodcastsIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Microphone
            VStack(spacing: 1) {
                // Mic head
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: 10, height: 14)

                // Mic stand
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 2, height: 6)

                // Base
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 10, height: 2)
            }

            // Floating hearts
            ForEach(0..<2, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(
                        x: CGFloat([8, -8][index]),
                        y: CGFloat([-6, -10][index])
                    )
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
        }
    }
}

// MARK: - Lullabies Icon (Moon + Stars)

struct LullabiesIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Crescent moon
            CrescentMoonShape()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(-30))

            // Stars
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: CGFloat([4, 6, 5][index])))
                    .foregroundColor(.white.opacity(0.9))
                    .offset(
                        x: CGFloat([10, 6, -8][index]),
                        y: CGFloat([-8, 8, -6][index])
                    )
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
        }
    }
}

struct CrescentMoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Outer circle
        path.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        // Inner cutout (offset circle)
        let cutoutCenter = CGPoint(x: center.x + radius * 0.4, y: center.y - radius * 0.1)
        path.addArc(center: cutoutCenter, radius: radius * 0.7, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)

        return path
    }
}

// MARK: - Ambient Icon (Waves + Particles)

struct AmbientIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Circular waves
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3 + Double(index) * 0.2), lineWidth: 1.5)
                    .frame(width: CGFloat(10 + index * 6), height: CGFloat(10 + index * 6))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Meditation Icon (Lotus)

struct MeditationIcon: View {
    var isAnimating: Bool

    var body: some View {
        ZStack {
            // Lotus petals
            ForEach(0..<5, id: \.self) { index in
                LotusPoetal()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(Double(index) * 36 - 72))
                    .offset(y: -4)
            }

            // Center
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
    }
}

struct LotusPoetal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control: CGPoint(x: w, y: h * 0.5)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control: CGPoint(x: 0, y: h * 0.5)
        )

        return path
    }
}

// MARK: - Category Icon Factory

/// Factory to create category icons from string category name
struct CategoryIconFactory {
    static func icon(for categoryName: String, size: CGFloat = 48) -> some View {
        let type = CategoryIconType(rawValue: categoryName) ?? mapCategory(categoryName)
        return CategoryIconView(type: type, size: size)
    }

    private static func mapCategory(_ name: String) -> CategoryIconType {
        let lowercased = name.lowercased()

        if lowercased.contains("classic") || lowercased.contains("piano") || lowercased.contains("symphony") {
            return .classical
        } else if lowercased.contains("fairy") || lowercased.contains("story") || lowercased.contains("tale") {
            return .fairyTales
        } else if lowercased.contains("white") || lowercased.contains("noise") || lowercased.contains("static") {
            return .whiteNoise
        } else if lowercased.contains("nature") || lowercased.contains("rain") || lowercased.contains("ocean") || lowercased.contains("forest") {
            return .natureSounds
        } else if lowercased.contains("instrument") || lowercased.contains("harp") || lowercased.contains("guitar") {
            return .instrumental
        } else if lowercased.contains("children") || lowercased.contains("kid") || lowercased.contains("nursery") {
            return .childrensSongs
        } else if lowercased.contains("podcast") || lowercased.contains("voice") {
            return .podcasts
        } else if lowercased.contains("lullaby") || lowercased.contains("lullabies") || lowercased.contains("sleep") {
            return .lullabies
        } else if lowercased.contains("ambient") || lowercased.contains("atmosphere") {
            return .ambient
        } else if lowercased.contains("meditat") || lowercased.contains("calm") || lowercased.contains("zen") {
            return .meditation
        }

        return .lullabies // Default
    }
}

// MARK: - Preview

#Preview("Category Icons Grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
            ForEach(CategoryIconType.allCases, id: \.rawValue) { type in
                VStack(spacing: 8) {
                    CategoryIconView(type: type, size: 56)
                    Text(type.rawValue)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 100)
            }
        }
        .padding()
    }
    .background(Color.appBackground)
}

#Preview("Category Icons Sizes") {
    HStack(spacing: 20) {
        CategoryIconView(type: .classical, size: 32)
        CategoryIconView(type: .fairyTales, size: 48)
        CategoryIconView(type: .whiteNoise, size: 64)
        CategoryIconView(type: .natureSounds, size: 80)
    }
    .padding()
    .background(Color.appBackground)
}
