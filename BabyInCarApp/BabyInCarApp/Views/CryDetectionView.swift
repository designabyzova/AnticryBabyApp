//
//  CryDetectionView.swift
//  BabyInCarApp
//
//  User interface for AI-powered cry detection and emergency response
//

import SwiftUI

struct CryDetectionView: View {
    @StateObject private var emergencyService = EmergencyCryStopService.shared
    @StateObject private var cryDetection = CryDetectionService.shared
    @StateObject private var smartResponse = SmartCryResponseEngine.shared

    @State private var baby: Baby?
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Animation states
    @State private var pulseAnimation = false
    @State private var waveAnimation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    statusCard

                    // Main Control Button
                    mainControlButton

                    // Cry Type Indicator
                    if cryDetection.isCryDetected || emergencyService.isEmergencyModeActive {
                        cryTypeCard
                    }

                    // Phase Progress
                    if emergencyService.isEmergencyModeActive {
                        phaseProgressCard
                    }

                    // Audio Level Visualizer
                    if emergencyService.isAIMonitoringEnabled {
                        audioLevelVisualizer
                    }

                    // Quick Actions
                    quickActionsSection

                    // Info Card
                    infoCard
                }
                .padding()
            }
            .navigationTitle("Cry Detection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                        Button(action: { showingHistory = true }) {
                            Label("History", systemImage: "clock")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                CryDetectionSettingsView()
            }
            .sheet(isPresented: $showingHistory) {
                CryDetectionHistoryView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                loadBaby()
            }
        }
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusBackgroundColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(
                        emergencyService.isEmergencyModeActive ?
                            .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default,
                        value: pulseAnimation
                    )

                Circle()
                    .fill(statusBackgroundColor.opacity(0.3))
                    .frame(width: 90, height: 90)

                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)
            }
            .onAppear {
                if emergencyService.isEmergencyModeActive {
                    pulseAnimation = true
                }
            }
            .onChange(of: emergencyService.isEmergencyModeActive) { active in
                pulseAnimation = active
            }

            // Status Text
            Text(emergencyService.currentPhase.rawValue)
                .font(.title2)
                .fontWeight(.semibold)

            Text(emergencyService.currentPhase.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Detection Status
            if emergencyService.isAIMonitoringEnabled {
                HStack(spacing: 8) {
                    Circle()
                        .fill(cryDetection.isCryDetected ? Color.red : Color.green)
                        .frame(width: 8, height: 8)

                    Text(emergencyService.cryDetectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: statusColor.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }

    private var statusIcon: String {
        switch emergencyService.currentPhase {
        case .idle:
            return "ear.badge.waveform"
        case .listening:
            return "waveform.badge.mic"
        case .detected:
            return "exclamationmark.triangle.fill"
        case .attention, .transition, .sustained, .adapting:
            return "speaker.wave.3.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch emergencyService.currentPhase {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .detected:
            return .orange
        case .attention, .transition, .sustained, .adapting:
            return .purple
        case .complete:
            return .green
        }
    }

    private var statusBackgroundColor: Color {
        if cryDetection.isCryDetected {
            return .red
        }
        return statusColor
    }

    // MARK: - Main Control Button
    private var mainControlButton: some View {
        Button(action: toggleMonitoring) {
            HStack(spacing: 12) {
                Image(systemName: emergencyService.isAIMonitoringEnabled ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)

                Text(emergencyService.isAIMonitoringEnabled ? "Stop Monitoring" : "Start AI Monitoring")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(emergencyService.isAIMonitoringEnabled ? Color.red : Color.blue)
            )
            .foregroundColor(.white)
        }
    }

    // MARK: - Cry Type Card
    private var cryTypeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: emergencyService.detectedCryType.icon)
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Detected: \(emergencyService.detectedCryType.rawValue)")
                        .font(.headline)

                    Text(emergencyService.detectedCryType.suggestedAction)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Confidence indicator
                VStack {
                    Text("\(Int(cryDetection.confidenceLevel * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Intensity Bar
            VStack(alignment: .leading, spacing: 4) {
                Text("Cry Intensity")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(intensityColor)
                            .frame(width: geometry.size.width * cryDetection.cryIntensity)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var intensityColor: Color {
        if cryDetection.cryIntensity < 0.3 {
            return .green
        } else if cryDetection.cryIntensity < 0.6 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Phase Progress Card
    private var phaseProgressCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Response Progress")
                    .font(.headline)
                Spacer()
                Text(emergencyService.responseEffectiveness)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(effectivenessColor.opacity(0.2))
                    .foregroundColor(effectivenessColor)
                    .cornerRadius(8)
            }

            // Phase indicator
            HStack(spacing: 4) {
                ForEach(phases, id: \.self) { phase in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(phaseColor(for: phase))
                            .frame(width: 12, height: 12)

                        Text(phaseShortName(for: phase))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if phase != phases.last {
                        Rectangle()
                            .fill(isPhaseComplete(phase) ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }

            // Current phase progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(emergencyService.currentPhase.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(emergencyService.phaseProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: emergencyService.phaseProgress)
                    .tint(.purple)
            }

            // Current sound
            if let sound = smartResponse.currentSound {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.purple)
                    Text("Playing: \(sound.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var phases: [EmergencyCryStopService.CalmingPhase] {
        [.attention, .transition, .sustained, .complete]
    }

    private func phaseShortName(for phase: EmergencyCryStopService.CalmingPhase) -> String {
        switch phase {
        case .attention: return "Attn"
        case .transition: return "Calm"
        case .sustained: return "Sooth"
        case .complete: return "Done"
        default: return ""
        }
    }

    private func phaseColor(for phase: EmergencyCryStopService.CalmingPhase) -> Color {
        if emergencyService.currentPhase == phase {
            return .purple
        } else if isPhaseComplete(phase) {
            return .green
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func isPhaseComplete(_ phase: EmergencyCryStopService.CalmingPhase) -> Bool {
        let phaseOrder: [EmergencyCryStopService.CalmingPhase] = [.attention, .transition, .sustained, .complete]
        guard let currentIndex = phaseOrder.firstIndex(of: emergencyService.currentPhase),
              let phaseIndex = phaseOrder.firstIndex(of: phase) else {
            return false
        }
        return phaseIndex < currentIndex
    }

    private var effectivenessColor: Color {
        switch smartResponse.effectiveness {
        case .highlyEffective: return .green
        case .effective: return .green
        case .partiallyEffective: return .yellow
        case .notWorking: return .red
        case .unknown: return .gray
        }
    }

    // MARK: - Audio Level Visualizer
    private var audioLevelVisualizer: some View {
        VStack(spacing: 12) {
            Text("Audio Level")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: 12, height: barHeight(for: index))
                        .animation(.easeInOut(duration: 0.1), value: cryDetection.currentAudioLevel)
                }
            }
            .frame(height: 50)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / 20.0
        let level = cryDetection.currentAudioLevel * 5 // Amplify for visibility
        return level > threshold ? CGFloat(20.0 + Double(index) * 1.5) : 10
    }

    private func barColor(for index: Int) -> Color {
        if index < 7 {
            return .green
        } else if index < 14 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                // Manual Emergency Button
                Button(action: activateEmergencyMode) {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.title2)
                        Text("Emergency")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .foregroundColor(.red)
                }
                .disabled(emergencyService.isEmergencyModeActive)

                // Report Not Working
                Button(action: reportNotWorking) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.title2)
                        Text("Not Working")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .foregroundColor(.orange)
                }
                .disabled(!emergencyService.isEmergencyModeActive)

                // Baby Calmed
                Button(action: reportSuccess) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.title2)
                        Text("Calmed!")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                    .foregroundColor(.green)
                }
                .disabled(!emergencyService.isEmergencyModeActive)
            }
        }
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("How AI Cry Detection Works")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "waveform", text: "Analyzes audio frequency patterns")
                InfoRow(icon: "chart.bar.fill", text: "Classifies cry type (hunger, tired, pain, etc.)")
                InfoRow(icon: "arrow.triangle.branch", text: "Selects optimal soothing sounds")
                InfoRow(icon: "sparkles", text: "Adapts based on baby's response")
                InfoRow(icon: "book.closed.fill", text: "Learns what works for your baby")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.05))
        )
    }

    // MARK: - Actions
    private func loadBaby() {
        if let data = UserDefaults.standard.data(forKey: "activeBaby"),
           let loadedBaby = try? JSONDecoder().decode(Baby.self, from: data) {
            baby = loadedBaby
        } else {
            // Create a default baby for demo
            baby = Baby(name: "Baby", birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!)
        }
    }

    private func toggleMonitoring() {
        if emergencyService.isAIMonitoringEnabled {
            emergencyService.disableAIMonitoring()
        } else {
            guard let baby = baby else {
                errorMessage = "Please set up a baby profile first"
                showError = true
                return
            }

            Task {
                do {
                    try await emergencyService.enableAIMonitoring(for: baby)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func activateEmergencyMode() {
        guard let baby = baby else { return }
        emergencyService.activate(for: baby)
    }

    private func reportNotWorking() {
        guard let baby = baby else { return }
        emergencyService.reportNotWorking(for: baby)
    }

    private func reportSuccess() {
        guard let baby = baby else { return }
        emergencyService.reportSuccess(for: baby)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Settings View
struct CryDetectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var emergencyService = EmergencyCryStopService.shared

    @AppStorage("useSmartResponse") private var useSmartResponse = true
    @AppStorage("autoActivateOnCry") private var autoActivateOnCry = true
    @AppStorage("sensitivityLevel") private var sensitivityLevel = 0.5

    var body: some View {
        NavigationView {
            Form {
                Section("AI Response") {
                    Toggle("Use Smart AI Response", isOn: $useSmartResponse)
                    Toggle("Auto-Activate on Cry", isOn: $autoActivateOnCry)
                }

                Section("Detection Sensitivity") {
                    VStack {
                        Slider(value: $sensitivityLevel, in: 0.1...1.0)
                        HStack {
                            Text("Less Sensitive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("More Sensitive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Privacy") {
                    Text("Audio is analyzed on-device only. No recordings are stored or transmitted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: useSmartResponse) { newValue in
                emergencyService.setSmartResponseEnabled(newValue)
            }
        }
    }
}

// MARK: - History View
struct CryDetectionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [EmergencySession] = []

    var body: some View {
        NavigationView {
            List {
                if sessions.isEmpty {
                    Text("No sessions recorded yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sessions.reversed(), id: \.timestamp) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: session.cryType.icon)
                                    .foregroundColor(.orange)
                                Text(session.cryType.rawValue)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: session.wasSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(session.wasSuccessful ? .green : .red)
                            }

                            Text(session.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Duration: \(formatDuration(session.duration))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadHistory()
            }
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "EmergencySessions"),
           let loaded = try? JSONDecoder().decode([EmergencySession].self, from: data) {
            sessions = loaded
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Preview
#Preview {
    CryDetectionView()
}
