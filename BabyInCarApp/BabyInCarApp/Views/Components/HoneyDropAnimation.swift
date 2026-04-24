//
//  HoneyDropAnimation.swift
//  BabyInCarApp
//
//  "It Helped" feedback micro-interaction. A honey drop falls from the tap point
//  toward the hive reserve indicator (HiveReserveIndicator), tallying successful
//  soothing events. Reinforces the bee metaphor.
//

import SwiftUI
import Combine

// MARK: - Session-scoped honey counter
// Tallies "It Helped" taps within the current session. Persistent across app-wide views.
final class HiveReserveStore: ObservableObject {
    static let shared = HiveReserveStore()
    @Published private(set) var honeyCount: Int = 0
    /// 0.0–1.0 used to drive fill visualization; saturates at 20 taps.
    var fillLevel: Double { min(Double(honeyCount) / 20.0, 1.0) }

    func addDrop() {
        honeyCount += 1
    }

    private init() {}
}

// MARK: - Hive Reserve Indicator
/// Small hex with a rising honey fill. Place persistently in nav/tab bar or header.
struct HiveReserveIndicator: View {
    @ObservedObject private var store = HiveReserveStore.shared
    @State private var justGainedPulse = false

    var body: some View {
        HexCellFill(fill: store.fillLevel)
            .frame(width: 28, height: 28)
            .scaleEffect(justGainedPulse ? 1.25 : 1.0)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.6),
                value: justGainedPulse
            )
            .onReceive(store.$honeyCount.dropFirst()) { _ in
                justGainedPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    justGainedPulse = false
                }
            }
            .accessibilityLabel("Hive reserve")
            .accessibilityValue("\(store.honeyCount) helpful tracks")
    }
}

private struct HexCellFill: View {
    let fill: Double

    var body: some View {
        ZStack {
            HexShape()
                .fill(Color.appPrimaryLight.opacity(0.35))
            HexShape()
                .fill(
                    LinearGradient(
                        colors: [Color.appPrimaryLight, Color.appPrimary],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(height: geo.size.height * fill)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                )
            HexShape()
                .stroke(Color.honeyDeep, lineWidth: 1.5)
        }
    }
}

// MARK: - Drop animation overlay
/// Animates a drop falling from `origin` to the hive reserve. One-shot.
/// Host it as an overlay on the main view; pass `isTriggered` + `originInOverlay`.
struct HoneyDropOverlay: View {
    @Binding var isTriggered: Bool
    let origin: CGPoint
    let destination: CGPoint

    @State private var progress: CGFloat = 0

    var body: some View {
        Group {
            if isTriggered {
                HoneyDropShape()
                    .fill(Color.appPrimary)
                    .overlay(
                        HoneyDropShape().stroke(Color.honeyDeep.opacity(0.7), lineWidth: 1)
                    )
                    .frame(width: 18, height: 24)
                    .position(
                        x: origin.x + (destination.x - origin.x) * progress,
                        y: origin.y + (destination.y - origin.y) * progress + sin(progress * .pi) * -20 // small arc
                    )
                    .opacity(Double(1.0 - max(0, progress - 0.85) * 6)) // fade near end
                    .onAppear {
                        progress = 0
                        withAnimation(.timingCurve(0.35, 0, 0.2, 1, duration: 0.7)) {
                            progress = 1
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                            HiveReserveStore.shared.addDrop()
                            HapticManager.shared.impact(style: .light)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                HapticManager.shared.impact(style: .light)
                            }
                            isTriggered = false
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Teardrop shape — pointed top, round bottom.
private struct HoneyDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.15),
            control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55)
        )
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.15),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.55)
        )
        return p
    }
}

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
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Convenience modifier

extension View {
    /// Attach the honey-drop overlay + auto-trigger helper.
    /// Usage: call `HiveReserveStore.shared.addDrop()` + play haptics directly,
    /// or host `HoneyDropOverlay(isTriggered:origin:destination:)` on the view.
    func honeyDropFeedback(trigger: Binding<Bool>, from origin: CGPoint, to destination: CGPoint) -> some View {
        overlay(HoneyDropOverlay(isTriggered: trigger, origin: origin, destination: destination))
    }
}

// MARK: - Honeycomb background pattern

/// Repeating hex outline pattern. Use as a subtle `.stroke` background for paywalls/hero sections.
struct HoneycombPattern: Shape {
    var cellSize: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = cellSize / 2
        // Pointy-top hex tiling: horizontal step = sqrt(3) * r, vertical step = 1.5 * r
        let dx = sqrt(3.0) * radius
        let dy = 1.5 * radius

        var row = 0
        var y: CGFloat = -radius
        while y < rect.maxY + radius {
            let xOffset: CGFloat = (row % 2 == 0) ? 0 : dx / 2
            var x: CGFloat = -radius + xOffset
            while x < rect.maxX + radius {
                addHex(to: &path, center: CGPoint(x: x, y: y), radius: radius)
                x += dx
            }
            y += dy
            row += 1
        }
        return path
    }

    private func addHex(to path: inout Path, center: CGPoint, radius: CGFloat) {
        for i in 0..<6 {
            let angle = (CGFloat.pi / 3) * CGFloat(i) - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
    }
}

// MARK: - Preview

#Preview("Reserve indicator") {
    VStack(spacing: 24) {
        HiveReserveIndicator()
        Button("Add honey") {
            HiveReserveStore.shared.addDrop()
        }
        .buttonStyle(.borderedProminent)
        .tint(.appPrimary)
    }
    .padding(40)
    .background(Color.appBackground)
}
