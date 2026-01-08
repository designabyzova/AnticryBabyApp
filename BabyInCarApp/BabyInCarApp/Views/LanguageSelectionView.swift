//
//  LanguageSelectionView.swift
//  BabyInCarApp
//
//  Language selection interface with elegant design
//  Supports 10 languages with RTL support
//

import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedLanguage: SupportedLanguage

    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header info
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundStyle(.appAccent.gradient)
                            .padding(.top, 20)

                        Text("Choose Your Language")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("Select the language for the app interface")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 32)

                    // Language List
                    VStack(spacing: 0) {
                        ForEach(SupportedLanguage.allCases) { language in
                            LanguageRow(
                                language: language,
                                isSelected: selectedLanguage == language
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedLanguage = language
                                    languageManager.setLanguage(language)

                                    // Haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            }

                            if language != SupportedLanguage.allCases.last {
                                Divider()
                                    .padding(.leading, 80)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    )
                    .padding(.horizontal, 20)

                    // Note about content language
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                            Text("About Content Language")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)

                        Text("This changes the app interface language. Audio content language is selected separately in your profile settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }
                .padding(.bottom, 40)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}

// MARK: - Language Row
struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Flag
            Text(language.flag)
                .font(.system(size: 36))
                .frame(width: 48, height: 48)

            // Language name
            VStack(alignment: .leading, spacing: 4) {
                Text(language.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(language.nativeDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.appAccent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            isSelected ? Color.appAccent.opacity(0.08) : Color.clear
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview
#Preview("Language Selection") {
    LanguageSelectionView()
}

#Preview("Language Row - Selected") {
    LanguageRow(language: .english, isSelected: true)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
}

#Preview("Language Row - Not Selected") {
    LanguageRow(language: .russian, isSelected: false)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
}

#Preview("All Languages") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(SupportedLanguage.allCases) { language in
                LanguageRow(language: language, isSelected: language == .english)
                if language != SupportedLanguage.allCases.last {
                    Divider()
                        .padding(.leading, 80)
                }
            }
        }
        .background(Color(.systemBackground))
        .padding()
    }
    .background(Color.appBackground)
}
