//
//  CryClassificationCard.swift
//  BabyInCarApp
//
//  AI cry type classification visualization
//  Shows confidence breakdown across all cry types with beautiful animations
//

import SwiftUI

/// Displays AI classification confidence for all cry types
struct CryClassificationCard: View {
    let detectedType: CryType
    let confidence: Double
    let classificationBreakdown: [CryType: Double]

    @State private var animateOnAppear = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Classification")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()

                // Model badge - shows if using real ML or simulated
                modelBadge
            }

            // Primary detected type - large display
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(colorForType(detectedType).opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: detectedType.icon)
                            .font(.system(size: 22))
                            .foregroundColor(colorForType(detectedType))
                    }

                    // Type and confidence
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detectedType.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Text("Confidence:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(confidence * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(colorForType(detectedType))
                        }
                    }

                    Spacer()

                    // Animated checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(colorForType(detectedType))
                        .scaleEffect(animateOnAppear ? 1.0 : 0.5)
                        .opacity(animateOnAppear ? 1.0 : 0.0)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorForType(detectedType).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(colorForType(detectedType).opacity(0.3), lineWidth: 1.5)
                    )
            )

            // Divider
            Divider()
                .padding(.vertical, 4)

            // All cry types breakdown
            VStack(spacing: 12) {
                Text("All Classifications")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(sortedClassifications, id: \.type) { item in
                        ClassificationRow(
                            type: item.type,
                            confidence: item.confidence,
                            isDetected: item.type == detectedType,
                            animate: animateOnAppear
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                animateOnAppear = true
            }
        }
    }

    // MARK: - Helper Types

    private struct ClassificationItem {
        let type: CryType
        let confidence: Double
    }

    private var sortedClassifications: [ClassificationItem] {
        // Sort by confidence descending, but keep detected type first
        let items = classificationBreakdown.map { ClassificationItem(type: $0.key, confidence: $0.value) }
        return items.sorted { lhs, rhs in
            if lhs.type == detectedType { return true }
            if rhs.type == detectedType { return false }
            return lhs.confidence > rhs.confidence
        }
    }

    private func colorForType(_ type: CryType) -> Color {
        switch type {
        case .hunger: return .orange
        case .tired: return .indigo
        case .pain: return .red
        case .attention: return .blue
        case .discomfort: return .yellow
        case .general: return .purple
        case .unknown: return .gray
        }
    }

    /// Model badge showing if using real ML or estimated data
    private var modelBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRealMLData ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(isRealMLData ? "ML Active" : "Estimated")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    /// Detect if this is real ML data or simulated
    private var isRealMLData: Bool {
        // Real ML data has precise probabilities that don't sum perfectly to 1.0
        // Simulated data has artificially clean distributions
        let total = classificationBreakdown.values.reduce(0, +)
        // Real ML: total might be 0.97-1.03 due to softmax/normalization
        // Simulated: total is exactly 1.0 (from our algorithm)
        let isNormalized = abs(total - 1.0) < 0.001
        let hasMultipleValues = classificationBreakdown.count > 1

        // If we have multiple values and they're NOT perfectly normalized, it's likely real ML
        return hasMultipleValues && !isNormalized
    }
}

// MARK: - Classification Row

struct ClassificationRow: View {
    let type: CryType
    let confidence: Double
    let isDetected: Bool
    let animate: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundColor(colorForType)
                .frame(width: 20)

            // Type name
            Text(type.rawValue)
                .font(.caption)
                .foregroundColor(isDetected ? colorForType : .secondary)
                .fontWeight(isDetected ? .semibold : .regular)
                .frame(width: 100, alignment: .leading)

            // Confidence bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.gray.opacity(0.15))

                    // Filled portion
                    Capsule()
                        .fill(colorForType.opacity(isDetected ? 1.0 : 0.6))
                        .frame(width: geometry.size.width * (animate ? CGFloat(confidence) : 0))
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .fontWeight(isDetected ? .bold : .regular)
                .foregroundColor(isDetected ? colorForType : .secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .opacity(confidence > 0.05 ? 1.0 : 0.4) // Dim very low confidence items
    }

    private var colorForType: Color {
        switch type {
        case .hunger: return .orange
        case .tired: return .indigo
        case .pain: return .red
        case .attention: return .blue
        case .discomfort: return .yellow
        case .general: return .purple
        case .unknown: return .gray
        }
    }
}

// MARK: - Acoustic Features Card

/// Shows the raw acoustic features the AI uses for classification
struct AcousticFeaturesCard: View {
    let fundamentalFrequency: Float
    let spectralCentroid: Float
    let harmonicsStrength: [Float]
    let intensity: Float
    let harmonicToNoiseRatio: Float

    @State private var animateOnAppear = false

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                Text("Acoustic Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Feature grid
            VStack(spacing: 10) {
                FeatureRow(
                    icon: "waveform",
                    label: "Fundamental Freq",
                    value: "\(Int(fundamentalFrequency)) Hz",
                    color: .blue,
                    animate: animateOnAppear
                )

                FeatureRow(
                    icon: "chart.bar.fill",
                    label: "Spectral Centroid",
                    value: "\(Int(spectralCentroid)) Hz",
                    color: .purple,
                    animate: animateOnAppear
                )

                FeatureRow(
                    icon: "speaker.wave.3.fill",
                    label: "Intensity",
                    value: String(format: "%.1f%%", intensity * 100),
                    color: .orange,
                    animate: animateOnAppear
                )

                FeatureRow(
                    icon: "waveform.path",
                    label: "Harmonics (HNR)",
                    value: String(format: "%.2f", harmonicToNoiseRatio),
                    color: .green,
                    animate: animateOnAppear
                )
            }

            // Harmonics visualization
            if !harmonicsStrength.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Harmonic Structure")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        ForEach(Array(harmonicsStrength.prefix(8).enumerated()), id: \.offset) { index, strength in
                            VStack(spacing: 4) {
                                GeometryReader { geometry in
                                    VStack {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .cyan],
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )
                                            .frame(height: geometry.size.height * (animateOnAppear ? CGFloat(min(1.0, strength * 2)) : 0))
                                    }
                                }
                                .frame(height: 40)

                                Text("H\(index + 1)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateOnAppear = true
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let animate: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .scaleEffect(animate ? 1.0 : 0.8)
                .opacity(animate ? 1.0 : 0.0)
        }
    }
}

// MARK: - Previews

#Preview("Classification Card") {
    CryClassificationCard(
        detectedType: .hunger,
        confidence: 0.85,
        classificationBreakdown: [
            .hunger: 0.85,
            .tired: 0.45,
            .pain: 0.30,
            .attention: 0.20,
            .discomfort: 0.15,
            .general: 0.10
        ]
    )
    .padding()
}

#Preview("Acoustic Features") {
    AcousticFeaturesCard(
        fundamentalFrequency: 420,
        spectralCentroid: 850,
        harmonicsStrength: [0.8, 0.6, 0.4, 0.3, 0.2, 0.15, 0.1, 0.05],
        intensity: 0.65,
        harmonicToNoiseRatio: 0.72
    )
    .padding()
}
