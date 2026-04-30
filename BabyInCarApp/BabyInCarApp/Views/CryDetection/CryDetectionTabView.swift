//
//  CryDetectionTabView.swift
//  BabyInCarApp
//
//  Tab view for cry detection - displays detection status without actions
//

import SwiftUI

/// Tab view for cry detection
/// Shows audio waveform, detection progress, and identified cry type
/// No playlist actions - just detection display
struct CryDetectionTabView: View {
    @ObservedObject private var viewModel = CryDetectionViewModel.shared
    @State private var isActive = false

    var body: some View {
        ZStack {
            // Background gradient — Soothbee dusk (cream → lavender).
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

            // Subtle hive pattern — reinforces Soothbee brand in negative space.
            HoneycombBackdrop(
                tile: 52,
                strokeColor: Color.appPrimary.opacity(0.08),
                lineWidth: 1
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
                    } else if viewModel.isListening {
                        detectionProgressSection
                    }

                    // Manual override buttons
                    manualOverrideSection

                    // Error message
                    if let error = viewModel.error {
                        errorSection(error: error)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .onAppear {
            isActive = true
            viewModel.startDetection()
        }
        .onDisappear {
            isActive = false
            viewModel.stopDetection()
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
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: viewModel.statusColor.opacity(0.2), radius: 20, y: 10)
        )
        // Tiny Soothbee mascot peeks from the card — hovers gently while listening.
        .overlay(alignment: .topTrailing) {
            BrandBeeMini(size: 48, rotation: -10)
                .offset(x: 6, y: -18)
                .opacity(viewModel.isListening ? 1.0 : 0.85)
        }
    }

    // MARK: - Waveform Section

    private var waveformSection: some View {
        VStack(spacing: 12) {
            Text("Audio Level")
                .font(.headline)
                .foregroundColor(.secondary)

            // Waveform visualization
            AudioWaveformView(level: viewModel.audioLevel, isActive: viewModel.isListening)
                .frame(height: 60)

            // Audio detected indicator
            HStack {
                Circle()
                    .fill(viewModel.isAudioDetected ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)

                Text(viewModel.isAudioDetected ? "Sound detected" : "Waiting for audio...")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isListening {
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.purple)
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
        VStack(spacing: 12) {
            Text("Cry Type Identified")
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

#Preview {
    CryDetectionTabView()
        .environmentObject(AudioEngine.shared)
        .environmentObject(AppState())
}
