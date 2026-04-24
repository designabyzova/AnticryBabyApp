//
//  HomeView.swift
//  BabyInCarApp
//
//  Home page focused on cry detection with categories below
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignTokens.spacingL) {
                    // Hero header with time-aware greeting
                    heroHeader

                    // Cry Detection — primary component
                    InlineCryDetectionCard()
                        .environmentObject(audioEngine)

                    // Categories
                    categoriesSection
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.visible)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [Color.appBackground, Color.appWarmCream.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .id(languageManager.refreshID)
    }

    // MARK: - Hero Header with Time-Aware Greeting
    private var heroHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DesignTokens.spacingM) {
                Image("BrandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.appPrimary.opacity(0.18), radius: 6, x: 0, y: 3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(timeBasedGreeting)
                        .font(.appTitle)
                        .foregroundColor(.appText)

                    if let baby = appState.currentBaby {
                        HStack(spacing: DesignTokens.spacingS) {
                            Text(baby.displayName)
                                .font(.appBodyMedium)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appPrimary, .appSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("\u{2022}")
                                .foregroundColor(.appTextTertiary)

                            Text(baby.formattedAge)
                                .font(.appBody)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }

                Spacer()

                // Settings button
                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        Circle()
                            .fill(Color.appCardBackground)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Time indicator pill
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: timeIcon)
                    .font(.system(size: 12))
                Text(timeOfDayText)
                    .font(.appCaption)
            }
            .foregroundColor(.appTextSecondary)
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.vertical, DesignTokens.spacingXS)
            .background(
                Capsule()
                    .fill(Color.appPrimary.opacity(0.1))
            )
            .padding(.top, DesignTokens.spacingS)
        }
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return languageManager.localizedString("home.greeting.morning")
        case 12..<17: return languageManager.localizedString("home.greeting.afternoon")
        case 17..<21: return languageManager.localizedString("home.greeting.evening")
        default: return languageManager.localizedString("home.greeting.night")
        }
    }

    private var timeIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private var timeOfDayText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return languageManager.localizedString("home.morningTime")
        case 12..<17: return languageManager.localizedString("home.afternoonNapTime")
        case 17..<21: return languageManager.localizedString("home.eveningWindDown")
        default: return languageManager.localizedString("home.bedtimeMode")
        }
    }

    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(languageManager.localizedString("home.categories"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AudioCategory.allCases) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        CategoryCard(category: category)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: AudioCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundColor(Color.forCategory(category))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.forCategory(category).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(category.description)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
}
