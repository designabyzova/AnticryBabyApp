//
//  ChatbotView.swift
//  BabyInCarApp
//
//  AI-powered chat interface for natural language library discovery.
//

import SwiftUI

struct ChatbotView: View {
    @StateObject private var chatHistory = ChatHistory.shared
    @StateObject private var chatbotService = LibraryChatbotService.shared
    @StateObject private var audioEngine = AudioEngine.shared

    @State private var inputText: String = ""
    @State private var isVoiceInputActive: Bool = false
    @FocusState private var isInputFocused: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header with current playing info
            if audioEngine.playbackState.isPlaying, let track = audioEngine.currentTrack {
                NowPlayingBar(track: track)
            }

            // Chat messages
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatHistory.messages) { message in
                            ChatMessageView(
                                message: message,
                                onPlayTrack: handlePlayTrack,
                                onShowResearch: handleShowResearch
                            )
                            .id(message.id)
                        }

                        // Typing indicator
                        if chatbotService.isProcessing {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding()
                }
                .onChange(of: chatHistory.messages.count) { _ in
                    withAnimation {
                        if let lastId = chatHistory.messages.last?.id {
                            scrollProxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Quick actions
            QuickActionButtons(
                cryType: nil,
                isInCar: false,
                onAction: handleQuickAction
            )

            // Input bar
            ChatInputBar(
                text: $inputText,
                isVoiceActive: $isVoiceInputActive,
                isFocused: $isInputFocused,
                isProcessing: chatbotService.isProcessing,
                onSend: sendMessage,
                onVoiceToggle: toggleVoiceInput
            )
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ask Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func sendMessage() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        inputText = ""

        Task {
            _ = await chatbotService.processQuery(query)
        }
    }

    private func handleQuickAction(_ query: String) {
        inputText = query
        sendMessage()
    }

    private func handlePlayTrack(trackId: String) {
        guard let uuid = UUID(uuidString: trackId),
              let track = ContentLibraryService.shared.getTrack(by: uuid) else {
            return
        }

        audioEngine.play(track: track)
    }

    private func handleShowResearch(topic: ResearchTopic) {
        let query = "Explain \(topic.rawValue.replacingOccurrences(of: "_", with: " "))"
        handleQuickAction(query)
    }

    private func toggleVoiceInput() {
        isVoiceInputActive.toggle()
        // Voice input via system keyboard dictation
    }
}

// MARK: - Now Playing Bar

struct NowPlayingBar: View {
    let track: AudioTrack
    @StateObject private var audioEngine = AudioEngine.shared

    var body: some View {
        HStack(spacing: 12) {
            // Track icon
            Image(systemName: track.category.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Now Playing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // "Why this?" button
            Button(action: {}) {
                Text("Why?")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
            }

            // Play/Pause
            Button(action: { togglePlayback() }) {
                Image(systemName: audioEngine.playbackState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func togglePlayback() {
        if audioEngine.playbackState.isPlaying {
            audioEngine.pause()
        } else if audioEngine.playbackState == .paused {
            audioEngine.resume()
        } else if let track = audioEngine.currentTrack {
            audioEngine.play(track: track)
        } else {
            audioEngine.resume()
        }
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    let message: ChatMessage
    var onPlayTrack: ((String) -> Void)?
    var onShowResearch: ((ResearchTopic) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.sender == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 8) {
                // Message bubble
                if message.isTyping {
                    TypingIndicator()
                } else {
                    Text(formatMarkdown(message.text))
                        .padding(12)
                        .background(bubbleColor)
                        .foregroundColor(textColor)
                        .cornerRadius(16)
                }

                // Track recommendations
                if let recommendations = message.trackRecommendations, !recommendations.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(recommendations) { rec in
                            TrackRecommendationCard(
                                recommendation: rec,
                                onPlay: { onPlayTrack?(rec.trackId) }
                            )
                        }
                    }
                }

                // Citations
                if let citations = message.citations, !citations.isEmpty {
                    CitationsView(citations: citations)
                }

                // Action button
                if let action = message.action {
                    ActionButton(action: action, onTap: handleAction)
                }

                // Timestamp
                Text(message.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.sender == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var bubbleColor: Color {
        switch message.sender {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color(.secondarySystemGroupedBackground)
        case .system:
            return Color.gray.opacity(0.3)
        }
    }

    private var textColor: Color {
        message.sender == .user ? .white : .primary
    }

    private func formatMarkdown(_ text: String) -> AttributedString {
        // Simple markdown formatting
        do {
            return try AttributedString(markdown: text)
        } catch {
            return AttributedString(text)
        }
    }

    private func handleAction(_ action: ChatAction) {
        switch action {
        case .playTrack(let trackId, _):
            onPlayTrack?(trackId)
        case .showResearch(let topic):
            onShowResearch?(topic)
        default:
            break
        }
    }
}

// MARK: - Track Recommendation Card

struct TrackRecommendationCard: View {
    let recommendation: TrackRecommendation
    var onPlay: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: { onPlay?() }) {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Stats
                HStack(spacing: 8) {
                    if let successRate = recommendation.historicalSuccessRate {
                        Label("\(Int(successRate * 100))% success", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    Text(recommendation.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Spacer()

            // Research backing indicator
            if recommendation.researchBacking != nil {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Citations View

struct CitationsView: View {
    let citations: [ResearchCitation]
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "book.fill")
                    Text("Research Sources (\(citations.count))")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if isExpanded {
                ForEach(citations) { citation in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(citation.title)
                            .font(.caption)
                            .fontWeight(.medium)

                        Text("\(citation.authors), \(citation.year)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let action: ChatAction
    var onTap: ((ChatAction) -> Void)?

    var body: some View {
        Button(action: { onTap?(action) }) {
            HStack {
                Image(systemName: actionIcon)
                Text(actionTitle)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }

    private var actionIcon: String {
        switch action {
        case .playTrack:
            return "play.fill"
        case .playCategory:
            return "music.note.list"
        case .showInsights:
            return "chart.bar.fill"
        case .openLibrary:
            return "square.grid.2x2"
        case .enableSmartMode:
            return "car.fill"
        case .showResearch:
            return "book.fill"
        case .adjustVolume:
            return "speaker.wave.2.fill"
        case .none:
            return "arrow.right"
        }
    }

    private var actionTitle: String {
        switch action {
        case .playTrack(_, let title):
            return "Play \(title)"
        case .playCategory(let category):
            return "Play \(category)"
        case .showInsights:
            return "View Insights"
        case .openLibrary:
            return "Open Library"
        case .enableSmartMode:
            return "Enable Smart Mode"
        case .showResearch:
            return "Learn More"
        case .adjustVolume(let level):
            return "Set Volume to \(Int(level * 100))%"
        case .none:
            return "Continue"
        }
    }
}

// MARK: - Quick Action Buttons

struct QuickActionButtons: View {
    var cryType: CryType?
    var isInCar: Bool
    var onAction: ((String) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Button(action: { onAction?(action.query) }) {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon)
                            Text(action.title)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var actions: [QuickAction] {
        QuickAction.contextualActions(cryType: cryType, isInCar: isInCar)
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var isVoiceActive: Bool
    var isFocused: FocusState<Bool>.Binding
    var isProcessing: Bool
    var onSend: (() -> Void)?
    var onVoiceToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Voice input button
            Button(action: { onVoiceToggle?() }) {
                Image(systemName: isVoiceActive ? "mic.fill" : "mic")
                    .font(.title2)
                    .foregroundColor(isVoiceActive ? .red : .accentColor)
            }

            // Text input
            HStack {
                TextField("Ask me anything...", text: $text)
                    .textFieldStyle(.plain)
                    .focused(isFocused)
                    .disabled(isProcessing)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(20)

            // Send button
            Button(action: { onSend?() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(canSend ? .accentColor : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onAppear { animating = true }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatbotView()
    }
}
