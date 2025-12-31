//
//  SplashScreenView.swift
//  BabyInCarApp
//
//  Animated splash screen with logo reveal animation
//

import SwiftUI

/// Animated splash screen displayed on app launch
struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var backgroundOpacity: Double = 1
    @State private var starsVisible = false
    @State private var waveOffset: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var showContent = false

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            // Floating stars
            if starsVisible {
                FloatingStarsView()
                    .opacity(backgroundOpacity)
            }

            // Sound waves animation behind logo
            SoundWavesView(offset: waveOffset)
                .opacity(backgroundOpacity * 0.3)

            // Main content
            VStack(spacing: DesignTokens.spacingL) {
                // Logo
                SplashLogoView(isAnimating: isAnimating)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // App name
                VStack(spacing: DesignTokens.spacingXS) {
                    Text("AnticryBaby")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.appPrimary, .appSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Sweet Dreams on Every Ride")
                        .font(.appSubheadline)
                        .foregroundColor(.appTextSecondary)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Phase 1: Logo fade in and scale
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Phase 2: Stars appear
        withAnimation(.easeInOut(duration: 0.5).delay(0.4)) {
            starsVisible = true
        }

        // Phase 3: Text appears
        withAnimation(.easeInOut(duration: 0.6).delay(0.7)) {
            textOpacity = 1.0
        }

        // Phase 4: Start logo animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isAnimating = true

            // Sound wave animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                waveOffset = 100
            }
        }

        // Phase 5: Transition out after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                backgroundOpacity = 0
                logoScale = 1.5
                logoOpacity = 0
                textOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onFinished()
            }
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: animateGradient ?
                [Color.appWarmCream, Color.appPrimary.opacity(0.2), Color.appSecondary.opacity(0.1)] :
                [Color.appSecondary.opacity(0.1), Color.appWarmCream, Color.appPrimary.opacity(0.2)],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Splash Logo View

struct SplashLogoView: View {
    var isAnimating: Bool

    @State private var breatheScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appPrimary.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .opacity(glowOpacity)
                .scaleEffect(breatheScale * 1.2)

            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.appPrimary.opacity(0.8), Color.appSecondary.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .shadow(color: Color.appPrimary.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(breatheScale)

            // Inner decorations circle
            Circle()
                .fill(Color.appWarmCream.opacity(0.9))
                .frame(width: 110, height: 110)
                .scaleEffect(breatheScale)

            // Baby face illustration
            SplashBabyFace(isAnimating: isAnimating)
                .scaleEffect(breatheScale)

            // Floating musical notes
            ForEach(0..<3, id: \.self) { index in
                MiniMusicNote(delay: Double(index) * 0.3)
                    .offset(
                        x: CGFloat([45, -50, 40][index]),
                        y: CGFloat([-55, -45, 50][index])
                    )
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    breatheScale = 1.03
                    glowOpacity = 0.5
                }
            }
        }
    }
}

// MARK: - Splash Baby Face

struct SplashBabyFace: View {
    var isAnimating: Bool

    @State private var eyesClosed = false

    var body: some View {
        VStack(spacing: 6) {
            // Eyes
            HStack(spacing: 22) {
                SplashEye(isClosed: eyesClosed)
                SplashEye(isClosed: eyesClosed)
            }

            // Rosy cheeks
            HStack(spacing: 35) {
                Circle()
                    .fill(Color.appAccentCoral.opacity(0.5))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(Color.appAccentCoral.opacity(0.5))
                    .frame(width: 14, height: 14)
            }
            .offset(y: -4)

            // Peaceful smile
            SplashSmile()
                .frame(width: 24, height: 10)
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                // Blink animation
                withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true).delay(2.0)) {
                    eyesClosed = true
                }
            }
        }
    }
}

// MARK: - Splash Eye

struct SplashEye: View {
    var isClosed: Bool

    var body: some View {
        if isClosed {
            // Closed eye (curved line)
            ClosedEyeCurve()
                .stroke(Color.appTextSecondary.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 18, height: 8)
        } else {
            // Open eye
            ZStack {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 20, height: 16)
                    .overlay(
                        Ellipse()
                            .stroke(Color.appTextSecondary.opacity(0.3), lineWidth: 1)
                    )

                Circle()
                    .fill(Color.appTextSecondary.opacity(0.9))
                    .frame(width: 10, height: 10)

                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .offset(x: -2, y: -2)
            }
        }
    }
}

struct ClosedEyeCurve: Shape {
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

// MARK: - Splash Smile

struct SplashSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.3),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        return path
    }
}

extension SplashSmile: View {
    var body: some View {
        self
            .stroke(Color.appTextSecondary.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
}

// MARK: - Mini Music Note

struct MiniMusicNote: View {
    var delay: Double

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0.7

    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.appPrimary)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(delay)) {
                    offset = -8
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Floating Stars View

struct FloatingStarsView: View {
    @State private var stars: [StarData] = []

    var body: some View {
        GeometryReader { geometry in
            ForEach(stars) { star in
                Image(systemName: "star.fill")
                    .font(.system(size: star.size))
                    .foregroundColor(Color.appPrimary.opacity(star.opacity))
                    .position(star.position)
                    .animation(
                        .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                        value: star.opacity
                    )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        stars = (0..<15).map { _ in
            StarData(
                position: CGPoint(
                    x: CGFloat.random(in: 20...350),
                    y: CGFloat.random(in: 50...700)
                ),
                size: CGFloat.random(in: 6...12),
                opacity: Double.random(in: 0.2...0.6),
                duration: Double.random(in: 1.5...3.0),
                delay: Double.random(in: 0...1.5)
            )
        }
    }
}

struct StarData: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var duration: Double
    var delay: Double
}

// MARK: - Sound Waves View

struct SoundWavesView: View {
    var offset: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary.opacity(0.3), Color.appSecondary.opacity(0.2)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: waveHeight(for: index, offset: offset))
            }
        }
        .frame(height: 60)
    }

    private func waveHeight(for index: Int, offset: CGFloat) -> CGFloat {
        let phase = (CGFloat(index) * 0.5 + offset * 0.1)
        let height = 20 + sin(phase) * 20
        return max(8, height)
    }
}

// MARK: - Preview

#Preview("Splash Screen") {
    SplashScreenView {
        print("Splash finished")
    }
}

#Preview("Splash Logo Only") {
    ZStack {
        Color.appBackground
        SplashLogoView(isAnimating: true)
    }
}
