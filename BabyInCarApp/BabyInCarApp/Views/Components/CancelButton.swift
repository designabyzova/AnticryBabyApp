//
//  CancelButton.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import SwiftUI

struct CancelButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .accessibilityLabel("Cancel Emergency Mode")
        .accessibilityHint("Stops playback and returns to normal mode")
    }

    private func handleTap() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Animate press
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
            }
            action()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CancelButton {
            print("Cancel tapped")
        }

        Text("Cancel Button")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
