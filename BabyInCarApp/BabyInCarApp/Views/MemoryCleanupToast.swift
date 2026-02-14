//
//  MemoryCleanupToast.swift
//  BabyInCarApp
//
//  Created by SpecWeave Increment 0022
//  Non-intrusive toast notification for memory cleanup events
//

import SwiftUI

/// Toast notification shown when memory cleanup is triggered
/// AUTO-DISMISSES after 3 seconds, non-intrusive design
struct MemoryCleanupToast: View {
    let message: String
    let level: MemoryMonitor.MemoryWarningLevel
    @Binding var isShowing: Bool

    var body: some View {
        VStack {
            Spacer()

            if isShowing {
                HStack(spacing: 12) {
                    // Icon based on warning level
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Above tab bar and mini player
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
            }
        }
    }

    private var iconName: String {
        switch level {
        case .critical:
            return "checkmark.circle.fill"
        case .emergency:
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch level {
        case .critical:
            return Color.orange
        case .emergency:
            return Color.red
        default:
            return Color.blue
        }
    }
}

/// View modifier to add memory cleanup toast to any view
struct MemoryCleanupToastModifier: ViewModifier {
    @ObservedObject private var memoryMonitor = MemoryMonitor.shared
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastLevel: MemoryMonitor.MemoryWarningLevel = .normal

    func body(content: Content) -> some View {
        ZStack {
            content

            MemoryCleanupToast(
                message: toastMessage,
                level: toastLevel,
                isShowing: $showToast
            )
        }
        .onChange(of: memoryMonitor.warningLevel) { newLevel in
            // Show toast when entering critical or emergency levels
            if newLevel == .critical || newLevel == .emergency {
                toastLevel = newLevel
                toastMessage = newLevel == .critical
                    ? "Memory optimized"
                    : "Emergency cleanup active"

                withAnimation {
                    showToast = true
                }

                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
        }
    }
}

extension View {
    /// Adds memory cleanup toast notification to the view
    /// Shows automatically when MemoryMonitor triggers cleanup
    func memoryCleanupToast() -> some View {
        modifier(MemoryCleanupToastModifier())
    }
}
