import SwiftUI
import WatchKit

/// Onboarding view explaining Apple Watch limitations and setup
struct WatchOnboardingView: View {
    @Binding var isPresented: Bool

    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1: Welcome
            welcomePage
                .tag(0)

            // Page 2: iPhone Requirement
            iPhoneRequirementPage
                .tag(1)

            // Page 3: Features
            featuresPage
                .tag(2)

            // Page 4: Get Started
            getStartedPage
                .tag(3)
        }
        .tabViewStyle(.page)
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Welcome to")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Baby in Car")
                .font(.headline)

            Text("Companion App")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Swipe to learn how it works")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - iPhone Requirement Page

    private var iPhoneRequirementPage: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.apple.watch")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("iPhone Required")
                .font(.headline)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "xmark.circle",
                    text: "Apple Watch cannot detect baby cries independently",
                    color: .red
                )

                InfoRow(
                    icon: "checkmark.circle",
                    text: "iPhone runs cry detection with advanced ML",
                    color: .green
                )

                InfoRow(
                    icon: "bell.badge",
                    text: "Alerts sent instantly to your watch",
                    color: .blue
                )
            }
            .padding(.horizontal)

            Text("Keep iPhone near baby with app running")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)

            Text("What You Can Do")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "bell", title: "Get Alerts", description: "Instant cry notifications with haptic")
                FeatureRow(icon: "music.note", title: "Play Music", description: "Cached favorites on watch")
                FeatureRow(icon: "iphone", title: "Remote Control", description: "Control iPhone playback")
                FeatureRow(icon: "timer", title: "Sleep Timer", description: "Auto-stop after set time")
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Get Started Page

    private var getStartedPage: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("Ready to Start")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                SetupStep(number: "1", text: "Open Baby in Car on iPhone")
                SetupStep(number: "2", text: "Enable cry detection")
                SetupStep(number: "3", text: "Keep iPhone near baby")
                SetupStep(number: "4", text: "Wear watch for instant alerts")
            }
            .padding(.horizontal)

            Button {
                isPresented = false
                WKInterfaceDevice.current().play(.success)
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)

            Text(text)
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SetupStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)

                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.caption2)
        }
    }
}

#Preview {
    WatchOnboardingView(isPresented: .constant(true))
}
