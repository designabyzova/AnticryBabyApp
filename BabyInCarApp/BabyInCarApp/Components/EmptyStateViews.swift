//
//  EmptyStateViews.swift
//  BabyInCarApp
//
//  Friendly empty state views with illustrations and action buttons
//

import SwiftUI

// MARK: - Base Empty State View

/// Reusable empty state container
struct EmptyStateView<Content: View>: View {
    let illustration: Content
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder illustration: () -> Content
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.illustration = illustration()
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingL) {
            illustration
                .frame(width: 200, height: 200)

            VStack(spacing: DesignTokens.spacingS) {
                Text(title)
                    .font(.appTitle3)
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXL)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, DesignTokens.spacingS)
            }
        }
        .padding(DesignTokens.spacingXL)
    }
}

// MARK: - Sleeping Baby Illustration

/// Animated sleeping baby face illustration
struct SleepingBabyIllustration: View {
    @State private var breatheScale: CGFloat = 1.0
    @State private var floatOffset: CGFloat = 0
    @State private var heartScale: [CGFloat] = [1.0, 1.0, 1.0]

    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.appPrimary.opacity(0.3),
                            Color.appPrimary.opacity(0.0)
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Floating hearts
            ForEach(0..<3, id: \.self) { index in
                HeartShape()
                    .fill(Color.appAccentCoral.opacity(0.6))
                    .frame(width: 16 + CGFloat(index * 4), height: 16 + CGFloat(index * 4))
                    .scaleEffect(heartScale[index])
                    .offset(
                        x: CGFloat([-40, 50, -20][index]),
                        y: CGFloat([-60 + floatOffset, -40 + floatOffset * 0.8, -70 + floatOffset * 1.2][index])
                    )
            }

            // Baby face circle
            Circle()
                .fill(Color.appWarmCream)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(Color.appPrimary.opacity(0.3), lineWidth: 3)
                )
                .scaleEffect(breatheScale)

            // Baby face features
            VStack(spacing: 8) {
                // Closed eyes (curved lines)
                HStack(spacing: 20) {
                    ClosedEyeShape()
                        .stroke(Color.appTextSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 16, height: 8)

                    ClosedEyeShape()
                        .stroke(Color.appTextSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 16, height: 8)
                }

                // Rosy cheeks
                HStack(spacing: 30) {
                    Circle()
                        .fill(Color.appAccentCoral.opacity(0.4))
                        .frame(width: 12, height: 12)

                    Circle()
                        .fill(Color.appAccentCoral.opacity(0.4))
                        .frame(width: 12, height: 12)
                }

                // Small smile
                SmileShape()
                    .stroke(Color.appTextSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 20, height: 8)
            }
            .scaleEffect(breatheScale)

            // Zzz animation
            ZzzView()
                .offset(x: 50, y: -30 + floatOffset)
        }
        .onAppear {
            // Breathing animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breatheScale = 1.03
            }

            // Float animation
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                floatOffset = -8
            }

            // Heart pulse animation
            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    heartScale[i] = 1.2
                }
            }
        }
    }
}

// MARK: - Music Notes Illustration

/// Floating music notes illustration
struct MusicNotesIllustration: View {
    @State private var noteOffsets: [CGFloat] = [0, 0, 0, 0, 0]
    @State private var noteOpacities: [Double] = [1, 1, 1, 1, 1]
    @State private var noteRotations: [Double] = [0, 0, 0, 0, 0]

    var body: some View {
        ZStack {
            // Background gradient circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.appSecondary.opacity(0.2),
                            Color.appSecondary.opacity(0.0)
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Music staff lines (simplified)
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.appTextTertiary.opacity(0.3))
                        .frame(width: 100, height: 2)
                }
            }

            // Floating notes
            ForEach(0..<5, id: \.self) { index in
                MusicNoteShape()
                    .fill(noteColors[index])
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(noteRotations[index]))
                    .opacity(noteOpacities[index])
                    .offset(
                        x: notePositions[index].x,
                        y: notePositions[index].y + noteOffsets[index]
                    )
            }

            // Central playlist icon
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28))
                        .foregroundColor(.appPrimary)
                )
                .shadow(color: Color.appPrimary.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        .onAppear {
            for i in 0..<5 {
                withAnimation(.easeInOut(duration: 2.0 + Double(i) * 0.3).repeatForever(autoreverses: true).delay(Double(i) * 0.2)) {
                    noteOffsets[i] = -15
                    noteOpacities[i] = 0.6
                    noteRotations[i] = Double([-15, 15, -10, 20, -12][i])
                }
            }
        }
    }

    private var noteColors: [Color] {
        [.appPrimary, .appSecondary, .appAccentMint, .appAccentCoral, .appPrimary.opacity(0.7)]
    }

    private var notePositions: [CGPoint] {
        [
            CGPoint(x: -60, y: -40),
            CGPoint(x: 65, y: -30),
            CGPoint(x: -50, y: 50),
            CGPoint(x: 55, y: 45),
            CGPoint(x: 0, y: -60)
        ]
    }
}

// MARK: - Cloud Download Illustration

/// Cloud with download arrow illustration
struct CloudDownloadIllustration: View {
    @State private var arrowOffset: CGFloat = 0
    @State private var cloudScale: CGFloat = 1.0
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.appAccentMint.opacity(0.2),
                            Color.appAccentMint.opacity(0.0)
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Cloud shape
            CloudShape()
                .fill(Color.appCardBackground)
                .frame(width: 120, height: 80)
                .overlay(
                    CloudShape()
                        .stroke(Color.appSecondary.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: Color.appSecondary.opacity(0.2), radius: 8, x: 0, y: 4)
                .scaleEffect(cloudScale)

            // Download arrow
            VStack(spacing: 4) {
                // Arrow body
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appPrimary)
                    .frame(width: 6, height: 25)

                // Arrow head
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
            }
            .offset(y: 20 + arrowOffset)

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 8, height: 8)
                        .opacity(dotOpacities[index])
                }
            }
            .offset(y: 70)
        }
        .onAppear {
            // Arrow bounce
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                arrowOffset = 8
            }

            // Cloud breathe
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                cloudScale = 1.05
            }

            // Dot animation sequence
            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.2)) {
                    dotOpacities[i] = 1.0
                }
            }
        }
    }
}

// MARK: - Search Empty Illustration

/// Empty search results illustration
struct SearchEmptyIllustration: View {
    @State private var magnifyScale: CGFloat = 1.0
    @State private var questionMarks: [CGFloat] = [0, 0, 0]

    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.appTextTertiary.opacity(0.1),
                            Color.appTextTertiary.opacity(0.0)
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Magnifying glass
            ZStack {
                // Glass circle
                Circle()
                    .stroke(Color.appPrimary, lineWidth: 6)
                    .frame(width: 70, height: 70)

                // Handle
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.appPrimary)
                    .frame(width: 8, height: 35)
                    .offset(x: 35, y: 35)
                    .rotationEffect(.degrees(45))

                // Sad face in glass
                VStack(spacing: 6) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.appTextSecondary)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.appTextSecondary)
                            .frame(width: 8, height: 8)
                    }

                    // Frown
                    FrownShape()
                        .stroke(Color.appTextSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 20, height: 8)
                }
            }
            .scaleEffect(magnifyScale)
            .offset(y: -10)

            // Question marks
            ForEach(0..<3, id: \.self) { index in
                Text("?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appTextTertiary.opacity(0.5))
                    .offset(
                        x: CGFloat([-50, 55, 0][index]),
                        y: CGFloat([-50, -40, 50][index]) + questionMarks[index]
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                magnifyScale = 1.08
            }

            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    questionMarks[i] = -10
                }
            }
        }
    }
}

// MARK: - Specific Empty State Views

/// Empty favorites view
struct NoFavoritesView: View {
    var onBrowse: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No Favorites Yet",
            message: "Tracks you love will appear here. Tap the heart on any track to add it to your favorites.",
            actionTitle: "Browse Tracks",
            action: onBrowse
        ) {
            SleepingBabyIllustration()
        }
    }
}

/// Empty playlists view
struct NoPlaylistsView: View {
    var onCreate: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No Playlists Yet",
            message: "Create your first playlist to organize your baby's favorite sounds and lullabies.",
            actionTitle: "Create Playlist",
            action: onCreate
        ) {
            MusicNotesIllustration()
        }
    }
}

/// Empty downloads view
struct NoDownloadsView: View {
    var onBrowse: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No Downloads",
            message: "Download tracks to listen offline when you're on the go with your little one.",
            actionTitle: "Browse Library",
            action: onBrowse
        ) {
            CloudDownloadIllustration()
        }
    }
}

/// Empty search results view
struct NoSearchResultsView: View {
    var searchQuery: String
    var onClear: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No Results Found",
            message: "We couldn't find anything matching \"\(searchQuery)\". Try a different search term.",
            actionTitle: "Clear Search",
            action: onClear
        ) {
            SearchEmptyIllustration()
        }
    }
}

/// Empty recent plays view
struct NoRecentPlaysView: View {
    var onExplore: () -> Void

    var body: some View {
        EmptyStateView(
            title: "Nothing Played Yet",
            message: "Start exploring our collection of soothing sounds and lullabies for your baby.",
            actionTitle: "Start Exploring",
            action: onExplore
        ) {
            MusicNotesIllustration()
        }
    }
}

// MARK: - Custom Shapes

/// Heart shape
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width * 0.5, y: height * 0.25))
        path.addCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.4),
            control1: CGPoint(x: width * 0.5, y: height * 0.1),
            control2: CGPoint(x: width * 0.2, y: height * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.9),
            control1: CGPoint(x: 0, y: height * 0.6),
            control2: CGPoint(x: width * 0.3, y: height * 0.8)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.4),
            control1: CGPoint(x: width * 0.7, y: height * 0.8),
            control2: CGPoint(x: width, y: height * 0.6)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.25),
            control1: CGPoint(x: width * 0.8, y: height * 0.1),
            control2: CGPoint(x: width * 0.5, y: height * 0.1)
        )

        return path
    }
}

/// Closed eye curve shape
struct ClosedEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: 0)
        )
        return path
    }
}

/// Smile curve shape
struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        return path
    }
}

/// Frown curve shape
struct FrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: 0)
        )
        return path
    }
}

/// Music note shape
struct MusicNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Note head (oval)
        path.addEllipse(in: CGRect(x: 0, y: h * 0.65, width: w * 0.5, height: h * 0.35))

        // Stem
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.1))

        // Flag
        path.addQuadCurve(
            to: CGPoint(x: w * 0.9, y: h * 0.4),
            control: CGPoint(x: w * 0.8, y: h * 0.1)
        )

        return path
    }
}

/// Cloud shape
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Main cloud body using circles
        path.addEllipse(in: CGRect(x: w * 0.1, y: h * 0.4, width: w * 0.35, height: h * 0.5))
        path.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.4, width: w * 0.35, height: h * 0.5))
        path.addEllipse(in: CGRect(x: w * 0.25, y: h * 0.15, width: w * 0.5, height: h * 0.6))
        path.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.5, width: w * 0.3, height: h * 0.4))

        return path
    }
}

/// Zzz sleep indicator
struct ZzzView: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("z")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.appPrimary.opacity(0.5))
            Text("z")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appPrimary.opacity(0.7))
                .offset(x: 4)
            Text("Z")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.appPrimary)
                .offset(x: 8)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                opacity = 0.4
            }
        }
    }
}

// MARK: - Preview

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 40) {
            Text("No Favorites")
                .font(.appHeadline)
            NoFavoritesView(onBrowse: {})

            Divider()

            Text("No Playlists")
                .font(.appHeadline)
            NoPlaylistsView(onCreate: {})

            Divider()

            Text("No Downloads")
                .font(.appHeadline)
            NoDownloadsView(onBrowse: {})

            Divider()

            Text("No Search Results")
                .font(.appHeadline)
            NoSearchResultsView(searchQuery: "lullaby", onClear: {})
        }
        .padding()
    }
    .background(Color.appBackground)
}

#Preview("Illustrations Only") {
    VStack(spacing: 30) {
        SleepingBabyIllustration()
        MusicNotesIllustration()
        CloudDownloadIllustration()
        SearchEmptyIllustration()
    }
    .padding()
    .background(Color.appBackground)
}
