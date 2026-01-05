//
//  LanguageBadge.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct LanguageBadge: View {
    let language: String
    let compact: Bool

    init(language: String, compact: Bool = false) {
        self.language = language
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(flagEmoji(for: language))
                .font(compact ? .caption2 : .caption)
            if !compact {
                Text(languageName(for: language))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }

    private func flagEmoji(for code: String) -> String {
        switch code {
        case "en": return "🇬🇧"
        case "ru": return "🇷🇺"
        case "multi": return "🌐"
        default: return "🌍"
        }
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "ru": return "Russian"
        case "multi": return "Instrumental"
        default: return code.uppercased()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        LanguageBadge(language: "en")
        LanguageBadge(language: "ru")
        LanguageBadge(language: "multi")

        HStack {
            LanguageBadge(language: "en", compact: true)
            LanguageBadge(language: "ru", compact: true)
            LanguageBadge(language: "multi", compact: true)
        }
    }
    .padding()
}
