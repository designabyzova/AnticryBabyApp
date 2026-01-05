//
//  DebugMemoryOverlay.swift
//  BabyInCarApp
//
//  Created by SpecWeave Increment 0022
//  Memory Leak Prevention System - Debug UI
//

import SwiftUI

#if DEBUG
/// Debug overlay showing real-time memory usage and warning levels
/// Only visible in DEBUG builds
struct DebugMemoryOverlay: View {
    @ObservedObject private var monitor = MemoryMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with warning level
            HStack {
                Text(monitor.warningLevel.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f MB", monitor.currentMemoryMB))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(monitor.warningLevel.color)
                }

                Spacer()

                Text(monitor.warningLevel.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(monitor.warningLevel.color.opacity(0.2))
                    .foregroundColor(monitor.warningLevel.color)
                    .cornerRadius(4)
            }

            Divider()

            // Memory breakdown
            if !monitor.memoryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BREAKDOWN")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(Array(monitor.memoryBreakdown.sorted(by: { $0.value > $1.value })), id: \.key) { component, mb in
                        HStack {
                            Text(component)
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(String(format: "%.1f MB", mb))
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(colorForMemory(mb))
                        }
                    }
                }
            }

            Divider()

            // Thresholds guide
            VStack(alignment: .leading, spacing: 2) {
                Text("THRESHOLDS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                thresholdRow(label: "Normal", threshold: "< 40 MB", color: .green)
                thresholdRow(label: "Warning", threshold: "40-45 MB", color: .yellow)
                thresholdRow(label: "Critical", threshold: "45-48 MB", color: .orange)
                thresholdRow(label: "Emergency", threshold: "> 48 MB", color: .red)
            }

            // Monitoring status
            HStack {
                Circle()
                    .fill(monitor.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)

                Text(monitor.isMonitoring ? "Monitoring" : "Stopped")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 50) // Below status bar
    }

    private func thresholdRow(label: String, threshold: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text(threshold)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func colorForMemory(_ mb: Double) -> Color {
        switch mb {
        case 0..<10: return .green
        case 10..<20: return .yellow
        default: return .orange
        }
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    /// Add debug memory overlay (DEBUG builds only)
    func debugMemoryOverlay() -> some View {
        #if DEBUG
        return self.overlay(
            DebugMemoryOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false) // Don't block interactions
        )
        #else
        return self
        #endif
    }
}

// MARK: - Preview

struct DebugMemoryOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()

            VStack {
                Spacer()
            }
        }
        .debugMemoryOverlay()
        .onAppear {
            // Simulate different memory levels for preview
            MemoryMonitor.shared.simulateMemoryLevel(42.5)
            MemoryMonitor.shared.startMonitoring()
        }
    }
}
#endif
