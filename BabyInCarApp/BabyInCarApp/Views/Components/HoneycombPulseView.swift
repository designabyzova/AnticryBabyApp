//
//  HoneycombPulseView.swift
//  BabyInCarApp
//
//  Signature visual for Soothbee cry detection.
//  A 7-cell honeycomb (1 center + 6 ring) where activation cascades outward
//  as detection confidence rises. Replaces the generic waveform.
//

import SwiftUI

struct HoneycombPulseView: View {
    /// Detection confidence, 0.0–1.0. Drives which rings are active.
    let confidence: Double

    /// Detected cry type (optional). Tints the active cells toward the type's category color.
    let detectedCryType: CryType?

    /// Whether the detector is actively listening. If false, the view is dim/static.
    let isListening: Bool

    @State private var idlePulse: Bool = false

    private var clampedConfidence: Double {
        max(0, min(1, confidence))
    }

    /// How many rings are lit:
    /// - 0 rings (center only) at confidence < 0.3
    /// - ring 1 (center + 6) at 0.3..<0.6
    /// - full (center + 6 visible with stronger glow) at >= 0.6
    private var ringActivation: Int {
        if !isListening { return 0 }
        if clampedConfidence < 0.3 { return 0 }
        if clampedConfidence < 0.6 { return 1 }
        return 2
    }

    private var tintColor: Color {
        guard let type = detectedCryType else { return .appPrimary }
        // Map mood/cry type to a semantic color. All tints are honey-toned variants
        // so the brand reads through regardless of detected type.
        switch type {
        case .hunger, .pain:
            return .appPrimary            // Honey gold — physiological urgency
        case .tired:
            return .appSecondary          // Dusk lavender — sleep cue
        case .attention:
            return .appTertiary           // Rose — comfort
        case .discomfort:
            return .appPrimaryDark        // Amber — alert
        case .general, .unknown:
            return .appPrimary
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let hexRadius = side * 0.16
            let ringDistance = hexRadius * 1.75
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Ring 2 (outer 6) — behind everything so it's a soft halo when active
                ForEach(0..<6, id: \.self) { i in
                    let pos = outerPosition(i, center: center, distance: ringDistance * 1.55)
                    HexCell(
                        radius: hexRadius * 0.85,
                        isFilled: ringActivation >= 2,
                        color: tintColor.opacity(0.35),
                        glowIntensity: ringActivation >= 2 ? 0.6 : 0
                    )
                    .position(pos)
                    .animation(
                        .spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping),
                        value: ringActivation
                    )
                }

                // Ring 1 (inner 6)
                ForEach(0..<6, id: \.self) { i in
                    let pos = outerPosition(i, center: center, distance: ringDistance)
                    HexCell(
                        radius: hexRadius,
                        isFilled: ringActivation >= 1,
                        color: tintColor.opacity(ringActivation >= 2 ? 0.85 : 0.6),
                        glowIntensity: ringActivation >= 1 ? 0.8 : 0
                    )
                    .position(pos)
                    .animation(
                        .spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)
                            .delay(Double(i) * 0.03),
                        value: ringActivation
                    )
                }

                // Center cell — always pulses when listening (idle + active states)
                HexCell(
                    radius: hexRadius,
                    isFilled: true,
                    color: tintColor,
                    glowIntensity: isListening ? 1.0 : 0
                )
                .scaleEffect(idlePulse && isListening && ringActivation == 0 ? 1.08 : 1.0)
                .position(center)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: idlePulse
                )
            }
        }
        .onAppear {
            idlePulse = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isListening ? "Listening for cry" : "Not listening")
        .accessibilityValue("Confidence \(Int(clampedConfidence * 100)) percent")
    }

    /// Positions the i-th cell in a pointy-top hex ring around `center` at `distance`.
    private func outerPosition(_ i: Int, center: CGPoint, distance: CGFloat) -> CGPoint {
        // 60° steps, starting from -90° (top)
        let angle = (CGFloat.pi / 3) * CGFloat(i) - .pi / 2
        return CGPoint(
            x: center.x + distance * cos(angle),
            y: center.y + distance * sin(angle)
        )
    }
}

// MARK: - Single Hex Cell

private struct HexCell: View {
    let radius: CGFloat
    let isFilled: Bool
    let color: Color
    let glowIntensity: Double

    var body: some View {
        HexShape()
            .fill(isFilled ? color : color.opacity(0.12))
            .overlay(
                HexShape()
                    .stroke(color.opacity(isFilled ? 0.9 : 0.3), lineWidth: 1.5)
            )
            .frame(width: radius * 2, height: radius * 2)
            .shadow(
                color: color.opacity(glowIntensity * 0.5),
                radius: radius * 0.4 * glowIntensity,
                x: 0, y: 0
            )
    }
}

/// Pointy-top regular hexagon path.
private struct HexShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) / 2
        let cx = rect.midX
        let cy = rect.midY
        for i in 0..<6 {
            let angle = (CGFloat.pi / 3) * CGFloat(i) - .pi / 2
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("States") {
    VStack(spacing: 24) {
        Group {
            HoneycombPulseView(confidence: 0.0, detectedCryType: nil, isListening: true)
                .frame(height: 220)
            HoneycombPulseView(confidence: 0.45, detectedCryType: .hunger, isListening: true)
                .frame(height: 220)
            HoneycombPulseView(confidence: 0.9, detectedCryType: .tired, isListening: true)
                .frame(height: 220)
        }
    }
    .padding()
    .background(Color.appBackground)
}
