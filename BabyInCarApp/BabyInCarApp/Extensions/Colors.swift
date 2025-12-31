//
//  Colors.swift
//  BabyInCarApp
//
//  Premium calming color system for baby soothing app
//  Designed for visual comfort, accessibility, and a peaceful experience
//

import SwiftUI

// MARK: - Design Tokens
/// Centralized design tokens for consistent theming
enum DesignTokens {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // Corner Radius
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
    static let radiusXL: CGFloat = 24
    static let radiusFull: CGFloat = 9999

    // Animation
    static let animationFast: Double = 0.2
    static let animationNormal: Double = 0.35
    static let animationSlow: Double = 0.5
    static let springDamping: Double = 0.75
    static let springResponse: Double = 0.4

    // Shadows
    static let shadowRadiusS: CGFloat = 4
    static let shadowRadiusM: CGFloat = 8
    static let shadowRadiusL: CGFloat = 16
    static let shadowOpacity: Double = 0.08
}

extension Color {
    // MARK: - Primary Palette (Soft & Calming)

    /// Soft Lavender - Primary brand color, calming and trustworthy
    static let appPrimary = Color(hex: "9B8DC7")              // Soft Lavender

    /// Deeper Lavender - For hover states and emphasis
    static let appPrimaryDark = Color(hex: "7B6BA7")          // Deeper Lavender

    /// Light Lavender - For subtle backgrounds
    static let appPrimaryLight = Color(hex: "C4B8E0")         // Light Lavender

    /// Dreamy Blue - Secondary accent, peaceful sky feeling
    static let appSecondary = Color(hex: "89CFF0")            // Dreamy Blue

    /// Rose Pink - Tertiary accent, warm and nurturing
    static let appTertiary = Color(hex: "F4B8C5")             // Rose Pink

    // MARK: - Background Colors

    /// Main background - Warm cream for comfort
    static let appBackground = Color(hex: "FDF9F3")           // Warm Cream

    /// Dark mode background - Deep slate, easy on eyes (reduced blue)
    static let appBackgroundDark = Color(hex: "1C1917")       // Deep Warm Black

    /// Card/Surface background - Clean white
    static let appCardBackground = Color(hex: "FFFFFF")       // Pure White

    /// Dark mode card - Warm charcoal (reduced blue light)
    static let appCardBackgroundDark = Color(hex: "292524")   // Warm Charcoal

    /// Elevated surface (modals, sheets)
    static let appSurface = Color(hex: "FEFEFE")              // Cloud White

    /// Dark mode surface - Warmer tone for comfort
    static let appSurfaceDark = Color(hex: "352F2E")          // Warm Slate

    // MARK: - Night Mode Colors (Ultra Low Blue Light)

    /// Night mode background - Extremely warm, minimal blue
    static let appNightBackground = Color(hex: "1A1614")      // Deep Sepia

    /// Night mode card background
    static let appNightCard = Color(hex: "262220")            // Warm Dark

    /// Night mode surface
    static let appNightSurface = Color(hex: "302A28")         // Warm Elevated

    // MARK: - Text Colors

    /// Primary text - Readable dark blue-gray
    static let appText = Color(hex: "2D3142")                 // Ink Blue

    /// Secondary text - Softer for less emphasis
    static let appTextSecondary = Color(hex: "6B7280")        // Slate Gray

    /// Tertiary text - For hints and captions
    static let appTextTertiary = Color(hex: "9CA3AF")         // Light Gray

    /// Light text - For dark backgrounds
    static let appTextLight = Color(hex: "F9FAFB")            // Off White

    /// Muted light text - For dark mode secondary
    static let appTextMuted = Color(hex: "D1D5DB")            // Muted White

    /// Warm light text - For night mode (reduced blue)
    static let appTextWarmLight = Color(hex: "E8DDD4")        // Warm Cream Text

    /// Warm muted text - Night mode secondary
    static let appTextWarmMuted = Color(hex: "A8998C")        // Warm Taupe

    // MARK: - Accent Colors for Dark/Night Mode

    /// Soft Warm Coral - Accent for dark mode
    static let appAccentCoral = Color(hex: "E8A090")          // Soft Coral

    /// Gentle Mint - For positive states in dark mode
    static let appAccentMint = Color(hex: "8CD4B8")           // Soft Mint

    /// Warm Cream - For highlights in dark mode
    static let appWarmCream = Color(hex: "F5EDE4")            // Warm Cream

    // MARK: - Status Colors (Softer for baby app context)

    /// Success - Gentle mint green
    static let appSuccess = Color(hex: "6EBF8B")              // Soft Mint

    /// Warning - Warm peach
    static let appWarning = Color(hex: "F5A962")              // Soft Peach

    /// Danger - Muted coral (not alarming)
    static let appDanger = Color(hex: "E87E7E")               // Soft Coral

    /// Info - Sky blue
    static let appInfo = Color(hex: "7EC8E3")                 // Sky Blue

    // MARK: - Category Colors (Harmonious Palette)

    /// Classical Music - Elegant purple
    static let classicalColor = Color(hex: "A78BDB")          // Lavender Purple

    /// Fairy Tales - Enchanting pink
    static let fairyTaleColor = Color(hex: "E8A4B8")          // Rose Pink

    /// White Noise - Calm blue
    static let whiteNoiseColor = Color(hex: "89B4D4")         // Ocean Blue

    /// Nature Sounds - Fresh sage green
    static let natureColor = Color(hex: "8BC49E")             // Sage Green

    /// Instrumental - Warm honey
    static let instrumentalColor = Color(hex: "E5C07B")       // Honey Gold

    /// Children's Songs - Cheerful sky
    static let childrenSongsColor = Color(hex: "7DB9DE")      // Baby Blue

    /// Podcasts - Friendly coral
    static let podcastColor = Color(hex: "E09D94")            // Soft Coral

    // MARK: - Special Purpose Colors

    /// Emergency button glow (attention without panic)
    static let emergencyGlow = Color(hex: "F08080")           // Light Coral

    /// Sleep/night mode accent
    static let sleepAccent = Color(hex: "6366A5")             // Twilight Purple

    /// Premium/gold accent
    static let premiumAccent = Color(hex: "D4AF37")           // Soft Gold

    // MARK: - Gradients

    /// Primary gradient - Lavender to blue (main brand)
    static let primaryGradient = LinearGradient(
        colors: [appPrimary, appSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dreamy gradient - For onboarding and hero sections
    static let dreamyGradient = LinearGradient(
        colors: [
            Color(hex: "FDF9F3"),  // Warm cream
            Color(hex: "E8E0F0"),  // Light lavender
            Color(hex: "D4E5F7")   // Soft blue
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Night gradient - For sleep mode (warm, minimal blue light)
    static let nightGradient = LinearGradient(
        colors: [
            Color(hex: "1A1614"),  // Deep sepia
            Color(hex: "262220"),  // Warm dark
            Color(hex: "302A28")   // Warm elevated
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Dark mode gradient - Warm dark with subtle depth
    static let darkModeGradient = LinearGradient(
        colors: [
            Color(hex: "1C1917"),  // Deep warm black
            Color(hex: "292524"),  // Warm charcoal
            Color(hex: "352F2E")   // Warm slate
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient - Subtle depth
    static let cardGradient = LinearGradient(
        colors: [Color.white, Color(hex: "F8F9FA")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Warm glow gradient - For emergency/attention
    static let warmGlowGradient = LinearGradient(
        colors: [
            Color(hex: "F5A962").opacity(0.8),
            Color(hex: "E87E7E").opacity(0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Calm gradient - For now playing backgrounds
    static let calmGradient = LinearGradient(
        colors: [
            Color(hex: "E8E0F0").opacity(0.5),
            Color(hex: "D4E5F7").opacity(0.3)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Category Color Helper

    static func forCategory(_ category: AudioCategory) -> Color {
        switch category {
        case .classicalMusic: return classicalColor
        case .fairyTales: return fairyTaleColor
        case .whiteNoise: return whiteNoiseColor
        case .natureSounds: return natureColor
        case .instrumental: return instrumentalColor
        case .childrenSongs: return childrenSongsColor
        case .podcasts: return podcastColor
        }
    }

    /// Get gradient for category
    static func gradientForCategory(_ category: AudioCategory) -> LinearGradient {
        let baseColor = forCategory(category)
        return LinearGradient(
            colors: [baseColor.opacity(0.7), baseColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shadow Helpers

    /// Standard soft shadow for cards
    static func cardShadow(opacity: Double = 0.08) -> some View {
        Color.black.opacity(opacity)
    }

    // MARK: - Hex Initializer

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isDarkMode: Bool = false
    @Published var isNightMode: Bool = false  // Extra dim for nighttime use with minimal blue light

    // MARK: - Background Colors

    var backgroundColor: Color {
        if isNightMode {
            return .appNightBackground
        }
        return isDarkMode ? .appBackgroundDark : .appBackground
    }

    var cardBackgroundColor: Color {
        if isNightMode {
            return .appNightCard
        }
        return isDarkMode ? .appCardBackgroundDark : .appCardBackground
    }

    var surfaceColor: Color {
        if isNightMode {
            return .appNightSurface
        }
        return isDarkMode ? .appSurfaceDark : .appSurface
    }

    // MARK: - Text Colors

    var textColor: Color {
        if isNightMode {
            return .appTextWarmLight
        }
        return isDarkMode ? .appTextLight : .appText
    }

    var secondaryTextColor: Color {
        if isNightMode {
            return .appTextWarmMuted
        }
        return isDarkMode ? .appTextMuted : .appTextSecondary
    }

    var tertiaryTextColor: Color {
        if isNightMode {
            return Color(hex: "7A6E64")  // Warm tertiary
        }
        return isDarkMode ? Color(hex: "6B7280") : .appTextTertiary
    }

    // MARK: - Accent Colors

    var primaryColor: Color {
        if isNightMode {
            return Color(hex: "C4A89C")  // Warm lavender for night
        }
        return isDarkMode ? .appPrimaryLight : .appPrimary
    }

    var accentColor: Color {
        if isNightMode {
            return .appAccentCoral
        }
        return isDarkMode ? .appSecondary : .appPrimary
    }

    // MARK: - Gradients

    /// Background gradient based on mode
    var backgroundGradient: LinearGradient {
        if isNightMode {
            return .nightGradient
        } else if isDarkMode {
            return .darkModeGradient
        } else {
            return .dreamyGradient
        }
    }

    // MARK: - Brightness Control

    /// Screen brightness multiplier for night mode
    var brightnessMultiplier: Double {
        if isNightMode {
            return 0.7  // Dim screen in night mode
        }
        return 1.0
    }

    /// Whether to use reduced blue light
    var useReducedBlueLight: Bool {
        isNightMode || isDarkMode
    }

    // MARK: - Mode Switching

    /// Automatically switch to night mode based on time
    func updateModeForTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        // Night mode between 9 PM and 6 AM
        isNightMode = (hour >= 21 || hour < 6) && isDarkMode
    }

    /// Enable night mode (ultra low blue light)
    func enableNightMode() {
        isDarkMode = true
        isNightMode = true
    }

    /// Disable night mode (return to dark mode)
    func disableNightMode() {
        isNightMode = false
    }

    /// Toggle between light and dark mode
    func toggleDarkMode() {
        isDarkMode.toggle()
        if !isDarkMode {
            isNightMode = false
        }
    }
}

// MARK: - View Modifiers for Theming

extension View {
    /// Apply card styling with consistent shadows
    func cardStyle(cornerRadius: CGFloat = DesignTokens.radiusM) -> some View {
        self
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(DesignTokens.shadowOpacity), radius: DesignTokens.shadowRadiusS, y: 2)
    }

    /// Apply elevated card styling (more prominent shadow)
    func elevatedCardStyle(cornerRadius: CGFloat = DesignTokens.radiusL) -> some View {
        self
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(DesignTokens.shadowOpacity), radius: DesignTokens.shadowRadiusM, y: 4)
    }

    /// Soft neumorphic effect (subtle depth)
    func neumorphic(cornerRadius: CGFloat = DesignTokens.radiusM) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appCardBackground)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: -2, y: -2)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 2, y: 2)
            )
    }
}

// MARK: - Color Preview

#Preview("Color Palette") {
    ScrollView {
        VStack(spacing: 24) {
            // Primary colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Primary Palette")
                    .font(.headline)

                HStack(spacing: 8) {
                    ColorSwatch(color: .appPrimary, name: "Primary")
                    ColorSwatch(color: .appSecondary, name: "Secondary")
                    ColorSwatch(color: .appTertiary, name: "Tertiary")
                }
            }

            // Backgrounds
            VStack(alignment: .leading, spacing: 8) {
                Text("Backgrounds")
                    .font(.headline)

                HStack(spacing: 8) {
                    ColorSwatch(color: .appBackground, name: "Background")
                    ColorSwatch(color: .appCardBackground, name: "Card")
                    ColorSwatch(color: .appSurface, name: "Surface")
                }
            }

            // Category colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Categories")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ColorSwatch(color: .classicalColor, name: "Classical")
                    ColorSwatch(color: .fairyTaleColor, name: "Fairy Tale")
                    ColorSwatch(color: .whiteNoiseColor, name: "White Noise")
                    ColorSwatch(color: .natureColor, name: "Nature")
                    ColorSwatch(color: .instrumentalColor, name: "Instrumental")
                    ColorSwatch(color: .childrenSongsColor, name: "Kids Songs")
                    ColorSwatch(color: .podcastColor, name: "Podcast")
                }
            }

            // Status colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.headline)

                HStack(spacing: 8) {
                    ColorSwatch(color: .appSuccess, name: "Success")
                    ColorSwatch(color: .appWarning, name: "Warning")
                    ColorSwatch(color: .appDanger, name: "Danger")
                    ColorSwatch(color: .appInfo, name: "Info")
                }
            }
        }
        .padding()
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 40)
                .shadow(radius: 2)

            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - LinearGradient Extension

extension LinearGradient {
    /// Dreamy gradient - For onboarding and hero sections
    static let dreamyGradient = LinearGradient(
        colors: [
            Color(hex: "FDF9F3"),  // Warm cream
            Color(hex: "E8E0F0"),  // Light lavender
            Color(hex: "D4E5F7")   // Soft blue
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Night gradient - For sleep mode (warm, minimal blue light)
    static let nightGradient = LinearGradient(
        colors: [
            Color(hex: "1A1614"),  // Deep sepia
            Color(hex: "262220"),  // Warm dark
            Color(hex: "302A28")   // Warm elevated
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Dark mode gradient - Warm dark with subtle depth
    static let darkModeGradient = LinearGradient(
        colors: [
            Color(hex: "1C1917"),  // Deep warm black
            Color(hex: "292524"),  // Warm charcoal
            Color(hex: "352F2E")   // Warm slate
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
