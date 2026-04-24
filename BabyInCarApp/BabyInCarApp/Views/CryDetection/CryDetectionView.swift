//
//  CryDetectionView.swift
//  BabyInCarApp
//
//  Main view for cry detection and playlist generation
//  Shows listening state, detected cry type, and controls
//

import SwiftUI
import Combine

// MARK: - CryDetectionView

/// Main view for cry detection feature
/// Displays audio waveform, detection progress, and detected cry type
struct CryDetectionView: View {
    @ObservedObject private var viewModel = CryDetectionViewModel.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient — Soothbee hive cream → light honey → lavender
                LinearGradient(
                    colors: [
                        Color(hex: "FDF6E8"),
                        Color(hex: "FBEAC2"),
                        Color(hex: "E8E0F0")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Status header
                        statusHeader

                        // Waveform visualization
                        waveformSection

                        // Detection progress or result
                        if viewModel.isStable {
                            detectedResultSection
                        } else {
                            detectionProgressSection
                        }

                        // Manual override buttons
                        if !viewModel.isStable || viewModel.showManualOverride {
                            manualOverrideSection
                        }

                        // Error message
                        if let error = viewModel.error {
                            errorSection(error: error)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Cry Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.stopDetection()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isListening {
                        Button {
                            viewModel.toggleManualOverride()
                        } label: {
                            Image(systemName: viewModel.showManualOverride ? "hand.raised.fill" : "hand.raised")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.startDetection()
            }
            .onDisappear {
                viewModel.stopDetection()
            }
            .onChange(of: viewModel.state) { newState in
                // Auto-dismiss modal when soothing playlist starts
                if case .playingSoothing = newState {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 8) {
            // Status icon with animation
            ZStack {
                // Pulse animation ring
                if viewModel.isListening && !viewModel.isStable {
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(.purple.opacity(0.3))
                        .scaleEffect(viewModel.pulseScale)
                        .opacity(2 - viewModel.pulseScale)
                }

                Circle()
                    .fill(viewModel.statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: viewModel.statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(viewModel.statusColor)
            }
            .frame(width: 100, height: 100)

            Text(viewModel.statusText)
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text(viewModel.statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: viewModel.statusColor.opacity(0.2), radius: 20, y: 10)
        )
    }

    // MARK: - Waveform / Honeycomb Section

    private var waveformSection: some View {
        VStack(spacing: 16) {
            // Soothbee signature: honeycomb pulse tied to live confidence
            HoneycombPulseView(
                confidence: viewModel.isStable ? viewModel.stableConfidence : viewModel.dominantConfidence,
                detectedCryType: viewModel.isStable ? viewModel.stableCryType : viewModel.dominantCryType,
                isListening: viewModel.isListening
            )
            .frame(height: 220)
            .padding(.top, 4)

            // Compact audio-level strip beneath the hive — shows raw mic activity
            AudioWaveformView(level: viewModel.audioLevel, isActive: viewModel.isListening)
                .frame(height: 36)
                .opacity(0.7)

            // Audio detected indicator
            HStack {
                Circle()
                    .fill(viewModel.isAudioDetected ? Color.appSuccess : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)

                Text(viewModel.isAudioDetected ? "Sound detected" : "Waiting for audio...")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isListening {
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.8))
        )
    }

    // MARK: - Detection Progress Section

    private var detectionProgressSection: some View {
        VStack(spacing: 16) {
            Text("Analyzing Cry Pattern")
                .font(.headline)

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: viewModel.stabilityProgress)
                    .tint(.purple)

                HStack {
                    Text("\(Int(viewModel.stabilityProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.purple)

                    Spacer()

                    Text("~\(Int((1 - viewModel.stabilityProgress) * 10)) sec remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Current dominant type (if any)
            if viewModel.dominantCryType != .unknown {
                HStack {
                    Image(systemName: viewModel.dominantCryType.iconName)
                        .foregroundColor(.purple)

                    Text("Detecting: \(viewModel.dominantCryType.displayName)")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(viewModel.dominantConfidence * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.purple.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.8))
        )
    }

    // MARK: - Detected Result Section

    private var detectedResultSection: some View {
        VStack(spacing: 20) {
            // Cry type result
            VStack(spacing: 12) {
                Text("Detected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Image(systemName: viewModel.stableCryType.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(cryTypeColor(viewModel.stableCryType))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.stableCryType.displayName.uppercased())
                            .font(.title2.bold())
                            .foregroundColor(.primary)

                        Text("\(Int(viewModel.stableConfidence * 100))% confidence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Cry type description
                Text(viewModel.stableCryType.suggestedAction)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cryTypeColor(viewModel.stableCryType).opacity(0.1))
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: cryTypeColor(viewModel.stableCryType).opacity(0.2), radius: 10)
            )

            // Start Soothing button
            Button {
                viewModel.startSoothingPlaylist()
            } label: {
                HStack {
                    Image(systemName: "music.note.list")
                    Text("Start Soothing Playlist")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
        }
    }

    // MARK: - Manual Override Section

    private var manualOverrideSection: some View {
        VStack(spacing: 12) {
            Text("Or select manually:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach([CryType.hunger, .tired, .pain], id: \.self) { cryType in
                    Button {
                        viewModel.selectCryType(cryType)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: cryType.iconName)
                                .font(.title2)
                            Text(cryType.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.stableCryType == cryType ? .white : cryTypeColor(cryType))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.stableCryType == cryType ? cryTypeColor(cryType) : cryTypeColor(cryType).opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.8))
        )
    }

    // MARK: - Error Section

    private func errorSection(error: CryDetectionError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if case .microphonePermissionDenied = error {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.subheadline.bold())
                .foregroundColor(.purple)
            }

            Button("Try Again") {
                viewModel.retryDetection()
            }
            .font(.subheadline.bold())
            .foregroundColor(.purple)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.orange.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private func cryTypeColor(_ cryType: CryType) -> Color {
        switch cryType {
        case .hunger: return .orange
        case .tired: return .purple
        case .pain: return .red
        case .attention: return .blue
        case .discomfort: return .yellow
        case .general: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let level: Float
    let isActive: Bool

    private let barCount: Int = 30
    @State private var bars: [Float] = Array(repeating: 0.1, count: 30)

    // Timer only created when view is active - prevents memory leak
    // Using TimelineView instead of Timer.publish for better SwiftUI lifecycle
    var body: some View {
        GeometryReader { geometry in
            waveformBars(geometry: geometry)
        }
        .onChange(of: level) { newLevel in
            updateBars(with: newLevel)
        }
        .task(id: isActive) {
            // Only run idle animation when active and level is low
            guard isActive else { return }
            while !Task.isCancelled && isActive {
                if level < 0.1 {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            for i in 0..<bars.count {
                                bars[i] = Float.random(in: 0.05...0.15)
                            }
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }

    @ViewBuilder
    private func waveformBars(geometry: GeometryProxy) -> some View {
        let barWidth: CGFloat = (geometry.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount)

        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                waveformBar(index: index, width: barWidth, height: geometry.size.height)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func waveformBar(index: Int, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: width)
            .frame(height: height * CGFloat(bars[index]))
    }

    private func updateBars(with level: Float) {
        withAnimation(.easeOut(duration: 0.1)) {
            // Shift bars left and add new level
            bars.removeFirst()
            bars.append(max(0.1, min(1.0, level)))
        }
    }
}

// Note: CryDetectionError and CryDetectionViewModel are defined in ViewModels/CryDetectionViewModel.swift

// Note: Color.init(hex:) is defined in Extensions/Colors.swift

// MARK: - Preview

#Preview {
    CryDetectionView()
}
