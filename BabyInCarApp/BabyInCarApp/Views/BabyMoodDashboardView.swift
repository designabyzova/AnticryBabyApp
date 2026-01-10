//
//  BabyMoodDashboardView.swift
//  BabyInCarApp
//
//  Revolutionary Baby Mood Intelligence Dashboard
//  Shows AI-powered mood analysis, predictions, and personalized insights
//

import SwiftUI
import Charts

// MARK: - Baby Mood Dashboard View
/// Main dashboard for Baby Mood Intelligence system
/// Displays real-time mood analysis, learning progress, and personalized recommendations
struct BabyMoodDashboardView: View {
    @StateObject private var viewModel = BabyMoodDashboardViewModel()
    @State private var selectedTab: DashboardTab = .mood
    @State private var showDetailedAnalysis = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with current mood
                    MoodHeaderCard(
                        moodState: viewModel.currentMoodState,
                        confidence: viewModel.confidence,
                        lastUpdated: viewModel.lastUpdated
                    )

                    // Tab selector
                    DashboardTabSelector(selectedTab: $selectedTab)

                    // Content based on selected tab
                    switch selectedTab {
                    case .mood:
                        MoodAnalysisSection(viewModel: viewModel)
                    case .patterns:
                        PatternsSection(viewModel: viewModel)
                    case .whatWorks:
                        DashboardWhatWorksSection(viewModel: viewModel)
                    case .tips:
                        ParentTipsSection(viewModel: viewModel)
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "E8F4FD"),
                        Color(hex: "F5E6FF"),
                        Color(hex: "FFF0F5")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Baby Intelligence")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDetailedAnalysis = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showDetailedAnalysis) {
                DetailedAnalysisSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.refreshData()
            }
        }
    }
}

// MARK: - Dashboard Tabs
enum DashboardTab: String, CaseIterable {
    case mood = "Mood"
    case patterns = "Patterns"
    case whatWorks = "What Works"
    case tips = "Tips"

    var icon: String {
        switch self {
        case .mood: return "face.smiling"
        case .patterns: return "chart.line.uptrend.xyaxis"
        case .whatWorks: return "checkmark.seal.fill"
        case .tips: return "lightbulb.fill"
        }
    }
}

// MARK: - Tab Selector
struct DashboardTabSelector: View {
    @Binding var selectedTab: DashboardTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    DashboardTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct DashboardTabButton: View {
    let tab: DashboardTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.purple : Color.white.opacity(0.8))
            )
            .foregroundColor(isSelected ? .white : .secondary)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mood Header Card
struct MoodHeaderCard: View {
    let moodState: BabyMoodState
    let confidence: Double
    let lastUpdated: Date?

    var body: some View {
        VStack(spacing: 16) {
            // Mood emoji with animated ring
            ZStack {
                // Confidence ring
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.2)
                    .foregroundColor(moodState.color)

                Circle()
                    .trim(from: 0, to: confidence)
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .foregroundColor(moodState.color)
                    .rotationEffect(.degrees(-90))

                // Mood emoji
                Text(moodState.emoji)
                    .font(.system(size: 60))
            }
            .frame(width: 120, height: 120)

            VStack(spacing: 4) {
                Text(moodState.title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text(moodState.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let updated = lastUpdated {
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }

            // Confidence indicator
            HStack {
                Text("AI Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(moodState.color)
            }
            .padding(.horizontal)

            ProgressView(value: confidence)
                .tint(moodState.color)
                .padding(.horizontal)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: moodState.color.opacity(0.2), radius: 20, y: 10)
        )
    }
}

// MARK: - Baby Mood State
enum BabyMoodState: String, CaseIterable {
    case happy = "happy"
    case content = "content"
    case sleepy = "sleepy"
    case hungry = "hungry"
    case uncomfortable = "uncomfortable"
    case fussy = "fussy"
    case crying = "crying"
    case unknown = "unknown"

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .content: return "😌"
        case .sleepy: return "😴"
        case .hungry: return "🍼"
        case .uncomfortable: return "😣"
        case .fussy: return "😟"
        case .crying: return "😢"
        case .unknown: return "🤔"
        }
    }

    var title: String {
        switch self {
        case .happy: return "Happy & Playful"
        case .content: return "Content & Calm"
        case .sleepy: return "Getting Sleepy"
        case .hungry: return "Might Be Hungry"
        case .uncomfortable: return "Uncomfortable"
        case .fussy: return "A Bit Fussy"
        case .crying: return "Needs Attention"
        case .unknown: return "Learning..."
        }
    }

    var description: String {
        switch self {
        case .happy: return "Baby seems to be in a great mood!"
        case .content: return "Relaxed and at peace"
        case .sleepy: return "Time for a nap might be near"
        case .hungry: return "Feeding time approaching"
        case .uncomfortable: return "Something might be bothering them"
        case .fussy: return "May need some soothing"
        case .crying: return "Let me help calm them down"
        case .unknown: return "Still learning your baby's patterns"
        }
    }

    var color: Color {
        switch self {
        case .happy: return .green
        case .content: return .blue
        case .sleepy: return .purple
        case .hungry: return .orange
        case .uncomfortable: return .yellow
        case .fussy: return .pink
        case .crying: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Mood Analysis Section
struct MoodAnalysisSection: View {
    @ObservedObject var viewModel: BabyMoodDashboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Contributing factors
            DashboardSectionHeader(title: "What's Contributing", icon: "chart.pie.fill")

            VStack(spacing: 12) {
                ForEach(viewModel.contributingFactors, id: \.name) { factor in
                    FactorRow(factor: factor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.8))
            )

            // Recent mood timeline
            DashboardSectionHeader(title: "Mood Timeline", icon: "clock.fill")

            MoodTimelineChart(dataPoints: viewModel.moodTimeline)
                .frame(height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.8))
                )

            // AI Reasoning
            if !viewModel.aiReasoning.isEmpty {
                DashboardSectionHeader(title: "AI Analysis", icon: "brain")

                Text(viewModel.aiReasoning)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.8))
                    )
            }
        }
    }
}

// MARK: - Factor Row
struct FactorRow: View {
    let factor: ContributingFactor

    var body: some View {
        HStack {
            Image(systemName: factor.icon)
                .font(.title3)
                .foregroundColor(factor.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.name)
                    .font(.subheadline.bold())

                Text(factor.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Impact indicator
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < factor.impact ? factor.color : Color.gray.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Contributing Factor Model
struct ContributingFactor: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let icon: String
    let color: Color
    let impact: Int // 1-5
}

// MARK: - Mood Timeline Chart
struct MoodTimelineChart: View {
    let dataPoints: [MoodDataPoint]

    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(dataPoints) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Mood", point.moodScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Mood", point.moodScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(values: [0, 2.5, 5, 7.5, 10]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let score = value.as(Double.self) {
                            Text(moodLabel(for: score))
                                .font(.caption2)
                        }
                    }
                }
            }
        } else {
            // Fallback for older iOS
            Text("Mood timeline requires iOS 16+")
                .foregroundColor(.secondary)
        }
    }

    private func moodLabel(for score: Double) -> String {
        switch score {
        case 0..<2.5: return "Upset"
        case 2.5..<5: return "Fussy"
        case 5..<7.5: return "Content"
        default: return "Happy"
        }
    }
}

// MARK: - Mood Data Point
struct MoodDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let moodScore: Double // 0-10
    let label: String
}

// MARK: - Patterns Section
struct PatternsSection: View {
    @ObservedObject var viewModel: BabyMoodDashboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Learned personality traits
            DashboardSectionHeader(title: "Baby's Personality", icon: "sparkles")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.personalityTraits, id: \.name) { trait in
                    PersonalityTraitCard(trait: trait)
                }
            }

            // Time patterns
            DashboardSectionHeader(title: "Time Patterns", icon: "calendar.badge.clock")

            VStack(spacing: 12) {
                ForEach(viewModel.timePatterns, id: \.time) { pattern in
                    TimePatternRow(pattern: pattern)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.8))
            )

            // Learning progress
            DashboardSectionHeader(title: "Learning Progress", icon: "graduationcap.fill")

            LearningProgressCard(
                sessionsAnalyzed: viewModel.totalSessions,
                patternsLearned: viewModel.patternsLearned,
                accuracyTrend: viewModel.accuracyTrend
            )
        }
    }
}

// MARK: - Personality Trait Card
struct PersonalityTraitCard: View {
    let trait: DashboardPersonalityTrait

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: trait.icon)
                    .foregroundColor(trait.color)
                Spacer()
                Text("\(Int(trait.value * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(trait.color)
            }

            Text(trait.name)
                .font(.subheadline.bold())

            Text(trait.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            ProgressView(value: trait.value)
                .tint(trait.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

// MARK: - Dashboard Personality Trait Model (UI display model, distinct from PersonalityTrait enum)
struct DashboardPersonalityTrait {
    let name: String
    let description: String
    let icon: String
    let color: Color
    let value: Double // 0-1
}

// MARK: - Time Pattern Row
struct TimePatternRow: View {
    let pattern: DashboardTimePattern

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(pattern.time)
                    .font(.subheadline.bold())
                Text(pattern.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(pattern.emoji)
                .font(.title2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dashboard Time Pattern Model (UI display model, distinct from TimePattern in BabyMoodProfile)
struct DashboardTimePattern {
    let time: String
    let description: String
    let emoji: String
}

// MARK: - Learning Progress Card
struct LearningProgressCard: View {
    let sessionsAnalyzed: Int
    let patternsLearned: Int
    let accuracyTrend: Double

    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text("\(sessionsAnalyzed)")
                    .font(.title.bold())
                    .foregroundColor(.purple)
                Text("Sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 40)

            VStack {
                Text("\(patternsLearned)")
                    .font(.title.bold())
                    .foregroundColor(.blue)
                Text("Patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 40)

            VStack {
                HStack(spacing: 2) {
                    Text(accuracyTrend >= 0 ? "+" : "")
                    Text("\(Int(accuracyTrend * 100))%")
                }
                .font(.title.bold())
                .foregroundColor(accuracyTrend >= 0 ? .green : .red)
                Text("Accuracy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.8))
        )
    }
}

// MARK: - Dashboard What Works Section (Placeholder - will be expanded in T-010)
struct DashboardWhatWorksSection: View {
    @ObservedObject var viewModel: BabyMoodDashboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            DashboardSectionHeader(title: "Top Effective Sounds", icon: "star.fill")

            ForEach(viewModel.topSounds, id: \.name) { sound in
                EffectiveSoundRow(sound: sound)
            }

            DashboardSectionHeader(title: "Best Combinations", icon: "sparkles")

            ForEach(viewModel.bestCombinations, id: \.id) { combo in
                CombinationCard(combination: combo)
            }
        }
    }
}

// MARK: - Effective Sound Row
struct EffectiveSoundRow: View {
    let sound: EffectiveSound

    var body: some View {
        HStack {
            Image(systemName: sound.icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.purple.opacity(0.1)))

            VStack(alignment: .leading, spacing: 2) {
                Text(sound.name)
                    .font(.subheadline.bold())
                Text("\(sound.timesUsed) times used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(Int(sound.successRate * 100))%")
                    .font(.headline.bold())
                    .foregroundColor(.green)
                Text("success")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.8))
        )
    }
}

// MARK: - Effective Sound Model
struct EffectiveSound {
    let name: String
    let icon: String
    let successRate: Double
    let timesUsed: Int
}

// MARK: - Combination Card
struct CombinationCard: View {
    let combination: SoundCombination

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Best for: \(combination.bestFor)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.purple))

                Spacer()

                Text("\(Int(combination.successRate * 100))% effective")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }

            HStack(spacing: 8) {
                ForEach(combination.sounds, id: \.self) { sound in
                    Text(sound)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.purple.opacity(0.1))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

// MARK: - Sound Combination Model
struct SoundCombination: Identifiable {
    let id = UUID()
    let sounds: [String]
    let bestFor: String
    let successRate: Double
}

// MARK: - Parent Tips Section
struct ParentTipsSection: View {
    @ObservedObject var viewModel: BabyMoodDashboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            DashboardSectionHeader(title: "Personalized Tips", icon: "lightbulb.fill")

            ForEach(viewModel.parentTips, id: \.id) { tip in
                ParentTipCard(tip: tip)
            }

            // Upcoming predictions
            if !viewModel.predictions.isEmpty {
                DashboardSectionHeader(title: "Upcoming Predictions", icon: "crystal.ball")

                ForEach(viewModel.predictions, id: \.id) { prediction in
                    DashboardPredictionCard(prediction: prediction)
                }
            }
        }
    }
}

// MARK: - Parent Tip Card
struct ParentTipCard: View {
    let tip: ParentTipItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline.bold())

                Text(tip.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let actionable = tip.actionableAdvice {
                    Text(actionable)
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

// MARK: - Parent Tip Item Model
struct ParentTipItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let actionableAdvice: String?
}

// MARK: - Dashboard Prediction Card
struct DashboardPredictionCard: View {
    let prediction: DashboardMoodPrediction

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(prediction.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(prediction.prediction)
                    .font(.subheadline.bold())
            }

            Spacer()

            Text(prediction.emoji)
                .font(.title)

            Text("\(Int(prediction.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.8))
        )
    }
}

// MARK: - Dashboard Mood Prediction Model
struct DashboardMoodPrediction: Identifiable {
    let id = UUID()
    let time: String
    let prediction: String
    let emoji: String
    let confidence: Double
}

// MARK: - Dashboard Section Header
struct DashboardSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Detailed Analysis Sheet
struct DetailedAnalysisSheet: View {
    @ObservedObject var viewModel: BabyMoodDashboardViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Full AI analysis
                    Text("AI Deep Analysis")
                        .font(.title2.bold())

                    Text(viewModel.fullAnalysis)
                        .font(.body)

                    Divider()

                    // Technical details
                    Text("Technical Details")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Model Version", value: "BabyMIM v1.0")
                        DetailRow(label: "Sessions Analyzed", value: "\(viewModel.totalSessions)")
                        DetailRow(label: "Last Training", value: viewModel.lastTrainingDate)
                        DetailRow(label: "Voice Print Quality", value: "\(Int(viewModel.voicePrintQuality * 100))%")
                        DetailRow(label: "Pattern Confidence", value: "\(Int(viewModel.confidence * 100))%")
                    }
                }
                .padding()
            }
            .navigationTitle("Detailed Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

// MARK: - View Model
@MainActor
class BabyMoodDashboardViewModel: ObservableObject {
    // Core state
    @Published var currentMoodState: BabyMoodState = .unknown
    @Published var confidence: Double = 0
    @Published var lastUpdated: Date?
    @Published var aiReasoning: String = ""
    @Published var fullAnalysis: String = ""

    // Contributing factors
    @Published var contributingFactors: [ContributingFactor] = []

    // Timeline
    @Published var moodTimeline: [MoodDataPoint] = []

    // Patterns
    @Published var personalityTraits: [DashboardPersonalityTrait] = []
    @Published var timePatterns: [DashboardTimePattern] = []
    @Published var totalSessions: Int = 0
    @Published var patternsLearned: Int = 0
    @Published var accuracyTrend: Double = 0

    // What Works
    @Published var topSounds: [EffectiveSound] = []
    @Published var bestCombinations: [SoundCombination] = []

    // Tips & Predictions
    @Published var parentTips: [ParentTipItem] = []
    @Published var predictions: [DashboardMoodPrediction] = []

    // Technical
    @Published var lastTrainingDate: String = "Today"
    @Published var voicePrintQuality: Double = 0

    // Services
    private let babyMIM = BabyMoodIntelligence.shared
    private let profileManager = BabyMoodProfileManager.shared

    init() {
        // Don't call loadData() in init - it publishes changes during view setup
        // which causes "Publishing changes from within view updates" warning.
        // Instead, loadData() is called via .task modifier in the view.
    }

    func refreshData() {
        loadData()
    }

    /// Called from view's .task modifier to load initial data
    func initialLoad() {
        loadData()
    }

    private func loadData() {
        // Load from BabyMIM and profile manager
        loadMoodState()
        loadContributingFactors()
        loadMoodTimeline()
        loadPersonalityTraits()
        loadTimePatterns()
        loadEffectiveSounds()
        loadParentTips()
        loadPredictions()
    }

    private func loadMoodState() {
        // Get current baby ID (simplified - in real app would come from baby manager)
        guard let babyId = getCurrentBabyId() else {
            currentMoodState = .unknown
            return
        }

        // Get profile
        guard let profile = profileManager.getProfile(for: babyId) else {
            currentMoodState = .unknown
            return
        }

        // Determine mood from recent patterns
        let moodScore = profile.recentMoodScore
        currentMoodState = moodStateFromScore(moodScore)
        confidence = profile.learningProgress
        lastUpdated = Date()

        // Get AI reasoning
        aiReasoning = babyMIM.getLastAnalysis()
        fullAnalysis = babyMIM.getDetailedAnalysis()

        // Technical stats
        totalSessions = profile.totalSoothingSessions
        voicePrintQuality = profile.voicePrintQuality
    }

    private func moodStateFromScore(_ score: Double) -> BabyMoodState {
        switch score {
        case 0..<2: return .crying
        case 2..<4: return .fussy
        case 4..<5: return .uncomfortable
        case 5..<6: return .content
        case 6..<7: return .sleepy
        case 7..<8.5: return .content
        case 8.5...10: return .happy
        default: return .unknown
        }
    }

    private func loadContributingFactors() {
        // Example factors - would come from ContextSignalCollector
        contributingFactors = [
            ContributingFactor(
                name: "Time of Day",
                detail: "Approaching usual nap time",
                icon: "clock.fill",
                color: .blue,
                impact: 4
            ),
            ContributingFactor(
                name: "Last Feed",
                detail: "2 hours ago",
                icon: "drop.fill",
                color: .orange,
                impact: 3
            ),
            ContributingFactor(
                name: "Activity Level",
                detail: "Moderate movement detected",
                icon: "figure.walk",
                color: .green,
                impact: 2
            ),
            ContributingFactor(
                name: "Environment",
                detail: "Quiet, comfortable temperature",
                icon: "house.fill",
                color: .purple,
                impact: 1
            )
        ]
    }

    private func loadMoodTimeline() {
        // Generate sample timeline - would come from stored history
        let now = Date()
        moodTimeline = (0..<12).map { i in
            let time = now.addingTimeInterval(-Double(11 - i) * 1800) // 30 min intervals
            let score = Double.random(in: 4...9) // Sample scores
            return MoodDataPoint(time: time, moodScore: score, label: "")
        }
    }

    private func loadPersonalityTraits() {
        guard let babyId = getCurrentBabyId(),
              let profile = profileManager.getProfile(for: babyId) else {
            return
        }

        let traits = profile.inferredPersonality
        personalityTraits = [
            DashboardPersonalityTrait(
                name: "Soothing Response",
                description: "How quickly baby responds to soothing sounds",
                icon: "waveform.path",
                color: .purple,
                value: traits.soothingResponsiveness
            ),
            DashboardPersonalityTrait(
                name: "Novelty Preference",
                description: "Preference for new vs familiar sounds",
                icon: "sparkles",
                color: .blue,
                value: traits.noveltyPreference
            ),
            DashboardPersonalityTrait(
                name: "Rhythm Sensitivity",
                description: "Response to rhythmic patterns",
                icon: "metronome.fill",
                color: .green,
                value: traits.rhythmSensitivity
            ),
            DashboardPersonalityTrait(
                name: "Pitch Preference",
                description: "Preference for higher or lower tones",
                icon: "tuningfork",
                color: .orange,
                value: traits.pitchPreference
            )
        ]

        patternsLearned = profile.learnedPatterns.count
        accuracyTrend = 0.12 // Would calculate from historical accuracy
    }

    private func loadTimePatterns() {
        timePatterns = [
            DashboardTimePattern(time: "6:00 AM - 8:00 AM", description: "Usually wakes happy, best mood", emoji: "🌅"),
            DashboardTimePattern(time: "10:00 AM - 11:00 AM", description: "First nap window", emoji: "😴"),
            DashboardTimePattern(time: "2:00 PM - 3:00 PM", description: "Sometimes fussy, needs attention", emoji: "🍼"),
            DashboardTimePattern(time: "7:00 PM - 8:00 PM", description: "Bedtime routine works best", emoji: "🌙")
        ]
    }

    private func loadEffectiveSounds() {
        topSounds = [
            EffectiveSound(name: "Pink Noise", icon: "waveform", successRate: 0.87, timesUsed: 42),
            EffectiveSound(name: "Heartbeat", icon: "heart.fill", successRate: 0.82, timesUsed: 38),
            EffectiveSound(name: "Rain Sounds", icon: "cloud.aquarium.fill", successRate: 0.79, timesUsed: 31),
            EffectiveSound(name: "Music Box", icon: "music.note", successRate: 0.75, timesUsed: 25)
        ]

        bestCombinations = [
            SoundCombination(sounds: ["Pink Noise", "Heartbeat"], bestFor: "Bedtime", successRate: 0.91),
            SoundCombination(sounds: ["Rain", "Ocean Waves"], bestFor: "Daytime Naps", successRate: 0.85),
            SoundCombination(sounds: ["Womb Sounds", "Shushing"], bestFor: "Urgent Calming", successRate: 0.88)
        ]
    }

    private func loadParentTips() {
        parentTips = [
            ParentTipItem(
                title: "Nap Time Approaching",
                description: "Based on your baby's patterns, they usually get sleepy around this time.",
                actionableAdvice: "Try starting the sleep routine in the next 15-20 minutes."
            ),
            ParentTipItem(
                title: "Pink Noise Works Best",
                description: "We've noticed pink noise is most effective for your baby, especially at bedtime.",
                actionableAdvice: nil
            ),
            ParentTipItem(
                title: "Feeding Window",
                description: "Your baby typically gets hungry around 2-3 hours after the last feed.",
                actionableAdvice: "The next feeding time might be around 4:30 PM."
            )
        ]
    }

    private func loadPredictions() {
        predictions = [
            DashboardMoodPrediction(time: "In 30 mins", prediction: "Likely to get sleepy", emoji: "😴", confidence: 0.78),
            DashboardMoodPrediction(time: "In 2 hours", prediction: "Feeding time", emoji: "🍼", confidence: 0.85),
            DashboardMoodPrediction(time: "Tonight 7PM", prediction: "Best bedtime window", emoji: "🌙", confidence: 0.82)
        ]
    }

    private func getCurrentBabyId() -> UUID? {
        // In real app, would get from BabyManager
        if let data = UserDefaults.standard.data(forKey: "activeBaby"),
           let baby = try? JSONDecoder().decode(Baby.self, from: data) {
            return baby.id
        }
        return nil
    }
}

// Note: Color.init(hex:) is defined in Extensions/Colors.swift

// MARK: - Preview
#Preview {
    BabyMoodDashboardView()
}
