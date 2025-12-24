//
//  Colors.swift
//  BabyInCarApp
//
//  Color definitions and theme
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let appPrimary = Color(hex: "6366F1")          // Indigo
    static let appPrimaryDark = Color(hex: "4F46E5")       // Dark Indigo
    static let appSecondary = Color(hex: "F472B6")         // Pink

    // MARK: - Background Colors
    static let appBackground = Color(hex: "F8FAFC")        // Light gray
    static let appBackgroundDark = Color(hex: "1E293B")    // Dark slate
    static let appCardBackground = Color.white
    static let appCardBackgroundDark = Color(hex: "334155")

    // MARK: - Text Colors
    static let appText = Color(hex: "1E293B")              // Dark slate
    static let appTextSecondary = Color(hex: "64748B")     // Gray
    static let appTextLight = Color.white

    // MARK: - Status Colors
    static let appSuccess = Color(hex: "10B981")           // Green
    static let appWarning = Color(hex: "F59E0B")           // Amber
    static let appDanger = Color(hex: "EF4444")            // Red

    // MARK: - Category Colors
    static let classicalColor = Color(hex: "8B5CF6")       // Purple
    static let fairyTaleColor = Color(hex: "EC4899")       // Pink
    static let whiteNoiseColor = Color(hex: "6366F1")      // Indigo
    static let natureColor = Color(hex: "10B981")          // Green
    static let instrumentalColor = Color(hex: "F59E0B")    // Amber
    static let childrenSongsColor = Color(hex: "3B82F6")   // Blue
    static let podcastColor = Color(hex: "EF4444")         // Red

    // MARK: - Gradient
    static let primaryGradient = LinearGradient(
        colors: [appPrimary, appSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white, Color(hex: "F1F5F9")],
        startPoint: .top,
        endPoint: .bottom
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
            (a, r, g, b) = (1, 1, 1, 0)
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

    var backgroundColor: Color {
        isDarkMode ? .appBackgroundDark : .appBackground
    }

    var cardBackgroundColor: Color {
        isDarkMode ? .appCardBackgroundDark : .appCardBackground
    }

    var textColor: Color {
        isDarkMode ? .appTextLight : .appText
    }

    var secondaryTextColor: Color {
        isDarkMode ? Color(hex: "94A3B8") : .appTextSecondary
    }
}
