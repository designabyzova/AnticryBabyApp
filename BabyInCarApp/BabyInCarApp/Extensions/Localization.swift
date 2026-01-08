//
//  Localization.swift
//  BabyInCarApp
//
//  Comprehensive localization utilities
//  Supports: EN, RU, ES, FR, DE, ZH-Hans, JA, PT, AR, IT
//

import SwiftUI

// MARK: - Localization Keys
/// Centralized localization keys for type-safe string access
enum L10n {
    // MARK: - Navigation
    enum Nav {
        static let profile = LocalizedStringKey("nav.profile")
        static let favorites = LocalizedStringKey("nav.favorites")
        static let library = LocalizedStringKey("nav.library")
        static let search = LocalizedStringKey("nav.search")
        static let insights = LocalizedStringKey("nav.insights")
        static let assistant = LocalizedStringKey("nav.assistant")
        static let downloads = LocalizedStringKey("nav.downloads")
        static let settings = LocalizedStringKey("nav.settings")
        static let babyIntelligence = LocalizedStringKey("nav.babyIntelligence")
        static let whatWorks = LocalizedStringKey("nav.whatWorks")
    }

    // MARK: - Buttons & Actions
    enum Button {
        static let play = LocalizedStringKey("button.play")
        static let pause = LocalizedStringKey("button.pause")
        static let shuffle = LocalizedStringKey("button.shuffle")
        static let save = LocalizedStringKey("button.save")
        static let cancel = LocalizedStringKey("button.cancel")
        static let done = LocalizedStringKey("button.done")
        static let delete = LocalizedStringKey("button.delete")
        static let download = LocalizedStringKey("button.download")
        static let upgrade = LocalizedStringKey("button.upgrade")
        static let getStarted = LocalizedStringKey("button.getStarted")
    }

    // MARK: - Home Greetings
    enum Home {
        enum Greeting {
            static let morning = LocalizedStringKey("home.greeting.morning")
            static let afternoon = LocalizedStringKey("home.greeting.afternoon")
            static let evening = LocalizedStringKey("home.greeting.evening")
            static let night = LocalizedStringKey("home.greeting.night")
        }
    }

    // MARK: - Emergency Cry Detection
    enum Emergency {
        static let title = LocalizedStringKey("emergency.title")
        static let subtitle = LocalizedStringKey("emergency.subtitle")
        static let startMonitoring = LocalizedStringKey("emergency.startMonitoring")
        static let stopMonitoring = LocalizedStringKey("emergency.stopMonitoring")
        static let listening = LocalizedStringKey("emergency.listening")
    }

    // MARK: - Cry Types
    enum Cry {
        static let hunger = LocalizedStringKey("cry.hunger")
        static let tired = LocalizedStringKey("cry.tired")
        static let discomfort = LocalizedStringKey("cry.discomfort")
        static let pain = LocalizedStringKey("cry.pain")
    }

    // MARK: - Player
    enum Player {
        static let nowPlaying = LocalizedStringKey("player.nowPlaying")
        static let upNext = LocalizedStringKey("player.upNext")
        static let queue = LocalizedStringKey("player.queue")
    }

    // MARK: - Empty States
    enum Empty {
        static let noFavorites = LocalizedStringKey("empty.noFavorites")
        static let noPlaylists = LocalizedStringKey("empty.noPlaylists")
        static let noDownloads = LocalizedStringKey("empty.noDownloads")
        static let searchNoResults = LocalizedStringKey("empty.searchNoResults")
    }

    // MARK: - Categories
    enum Category {
        static let lullabies = LocalizedStringKey("category.lullabies")
        static let classical = LocalizedStringKey("category.classical")
        static let nature = LocalizedStringKey("category.nature")
        static let fairyTales = LocalizedStringKey("category.fairyTales")
        static let ambient = LocalizedStringKey("category.ambient")
    }

    // MARK: - Settings
    enum Settings {
        static let audio = LocalizedStringKey("settings.audio")
        static let volume = LocalizedStringKey("settings.volume")
        static let sleepTimer = LocalizedStringKey("settings.sleepTimer")
        static let languages = LocalizedStringKey("settings.languages")
        static let about = LocalizedStringKey("settings.about")
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let welcome = LocalizedStringKey("onboarding.welcome")
        static let appName = LocalizedStringKey("onboarding.appName")
        static let tagline = LocalizedStringKey("onboarding.tagline")
        static let subtitle = LocalizedStringKey("onboarding.subtitle")
    }

    // MARK: - Premium
    enum Premium {
        static let unlockAll = LocalizedStringKey("premium.unlockAll")
        static let free = LocalizedStringKey("premium.free")
        static let premium = LocalizedStringKey("premium.premium")
    }

    // MARK: - Time
    enum Time {
        static let minutes = LocalizedStringKey("time.minutes")
        static let hours = LocalizedStringKey("time.hours")
    }

    // MARK: - Actions
    enum Action {
        static let addToFavorites = LocalizedStringKey("action.addToFavorites")
        static let removeFromFavorites = LocalizedStringKey("action.removeFromFavorites")
        static let addToPlaylist = LocalizedStringKey("action.addToPlaylist")
    }

    // MARK: - Alerts
    enum Alert {
        static let error = LocalizedStringKey("alert.error")
        static let confirm = LocalizedStringKey("alert.confirm")
        static let deletePlaylist = LocalizedStringKey("alert.deletePlaylist")
    }

    // MARK: - Status
    enum Status {
        static let downloading = LocalizedStringKey("status.downloading")
        static let loading = LocalizedStringKey("status.loading")
        static let ready = LocalizedStringKey("status.ready")
    }

    // MARK: - Insights
    enum Insights {
        static let overview = LocalizedStringKey("insights.overview")
        static let sessions = LocalizedStringKey("insights.sessions")
        static let accuracy = LocalizedStringKey("insights.accuracy")
        static let confidence = LocalizedStringKey("insights.confidence")
    }

    // MARK: - Baby Profile
    enum Baby {
        static let name = LocalizedStringKey("baby.name")
        static let birthDate = LocalizedStringKey("baby.birthDate")
        static let age = LocalizedStringKey("baby.age")
    }

    // MARK: - Search
    enum Search {
        static let placeholder = LocalizedStringKey("search.placeholder")
        static let recent = LocalizedStringKey("search.recent")
        static let popular = LocalizedStringKey("search.popular")
    }
}

// MARK: - String Extensions
extension String {
    /// Get localized string from key
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Get localized string with arguments
    func localized(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Supported Languages
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"
    case portuguese = "pt"
    case arabic = "ar"
    case italian = "it"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .chineseSimplified: return "简体中文"
        case .japanese: return "日本語"
        case .portuguese: return "Português"
        case .arabic: return "العربية"
        case .italian: return "Italiano"
        }
    }

    var nativeDisplayName: String {
        displayName
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .chineseSimplified: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .portuguese: return "🇵🇹"
        case .arabic: return "🇸🇦"
        case .italian: return "🇮🇹"
        }
    }

    /// Is this a right-to-left language?
    var isRTL: Bool {
        self == .arabic
    }
}

// MARK: - Language Manager
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            // Notify app to update language
            NotificationCenter.default.post(name: .languageChanged, object: currentLanguage)
        }
    }

    private init() {
        // Load saved language or default to device language
        if let savedLang = UserDefaults.standard.string(forKey: "app_language"),
           let language = SupportedLanguage(rawValue: savedLang) {
            self.currentLanguage = language
        } else {
            // Try to match device language
            let deviceLang = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = SupportedLanguage(rawValue: deviceLang) ?? .english
        }
    }

    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }
}

// MARK: - Notification
extension Notification.Name {
    static let languageChanged = Notification.Name("app.language.changed")
}

// MARK: - View Extension for RTL Support
extension View {
    /// Apply RTL layout based on current language
    func applyRTL() -> some View {
        self.environment(\.layoutDirection, LanguageManager.shared.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
    }
}
