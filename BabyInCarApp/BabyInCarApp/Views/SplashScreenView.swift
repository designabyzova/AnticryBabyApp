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
    @State private var textOpacity: Double = 0
    @State private var showContent = false

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            // Floating particles (calm magic effect)
            if starsVisible {
                FloatingParticlesView()
                    .opacity(backgroundOpacity)
            }

            // Subtle vignette (focus on center)
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.15)],
                center: .center,
                startRadius: 200,
                endRadius: 500
            )
            .ignoresSafeArea()
            .opacity(backgroundOpacity)

            // Main content
            VStack(spacing: DesignTokens.spacingL) {
                // Logo
                SplashLogoView(isAnimating: isAnimating)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // App name
                VStack(spacing: DesignTokens.spacingXS) {
                    Text("Soothbee")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.appPrimary, .appSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.appPrimary.opacity(0.3), radius: 8, x: 0, y: 4)

                    Text("Calm Baby, Anywhere")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .tracking(0.5)
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
    @State private var cloudOffset1: CGFloat = 0
    @State private var cloudOffset2: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient - warmer palette
            LinearGradient(
                colors: animateGradient ?
                    [Color.appWarmCream, Color(red: 0.95, green: 0.87, blue: 0.95), Color.appSecondary.opacity(0.15)] :
                    [Color.appSecondary.opacity(0.15), Color(red: 0.95, green: 0.87, blue: 0.95), Color.appWarmCream],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )

            // Floating cloud shapes (ultra-subtle depth)
            GeometryReader { geometry in
                // Cloud 1 - large, top-left
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100 + cloudOffset1, y: -50)

                // Cloud 2 - large, bottom-right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appPrimary.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 70,
                            endRadius: 220
                        )
                    )
                    .frame(width: 450, height: 450)
                    .offset(x: geometry.size.width - 250 + cloudOffset2, y: geometry.size.height - 200)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }

            // Slow cloud drift
            withAnimation(.easeInOut(duration: 15.0).repeatForever(autoreverses: true)) {
                cloudOffset1 = 30
            }

            withAnimation(.easeInOut(duration: 20.0).repeatForever(autoreverses: true)) {
                cloudOffset2 = -40
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
            // Outer glow - larger and softer
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appPrimary.opacity(0.3), Color.appSecondary.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .opacity(glowOpacity)
                .scaleEffect(breatheScale * 1.15)
                .blur(radius: 20)

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

            // Soothbee mascot (actual App Store icon)
            Image("BrandLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 118, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .scaleEffect(breatheScale)
                .shadow(color: Color.appPrimary.opacity(0.35), radius: 14, x: 0, y: 6)

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

@MainActor
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

// MARK: - Floating Particles View (Calm Magic Effect)

struct FloatingParticlesView: View {
    @State private var particles: [ParticleData] = []

    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                particle.color.opacity(particle.opacity),
                                particle.color.opacity(particle.opacity * 0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: particle.size / 2
                        )
                    )
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .offset(y: particle.yOffset)
                    .opacity(particle.currentOpacity)
                    .blur(radius: particle.blur)
                    .animation(
                        .easeInOut(duration: particle.duration)
                        .repeatForever(autoreverses: true)
                        .delay(particle.delay),
                        value: particle.yOffset
                    )
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        let colors: [Color] = [.appPrimary, .appSecondary, .appAccentMint, .white]

        particles = (0..<20).map { index in
            let yPos = CGFloat.random(in: 100...700)
            return ParticleData(
                position: CGPoint(
                    x: CGFloat.random(in: 30...360),
                    y: yPos
                ),
                size: CGFloat.random(in: 8...24),
                opacity: Double.random(in: 0.15...0.4),
                currentOpacity: Double.random(in: 0.1...0.3),
                duration: Double.random(in: 2.5...5.0),
                delay: Double.random(in: 0...2.0),
                yOffset: CGFloat.random(in: -15...15),
                blur: CGFloat.random(in: 3...8),
                color: colors[index % colors.count]
            )
        }
    }
}

struct ParticleData: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var currentOpacity: Double
    var duration: Double
    var delay: Double
    var yOffset: CGFloat
    var blur: CGFloat
    var color: Color
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
