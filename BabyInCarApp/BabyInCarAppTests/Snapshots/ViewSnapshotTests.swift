//
//  ViewSnapshotTests.swift
//  BabyInCarAppTests
//
//  Snapshot tests for SwiftUI views
//  Uses swift-snapshot-testing for visual regression testing
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import BabyInCarApp

final class ViewSnapshotTests: XCTestCase {

    // MARK: - Configuration

    override func setUp() {
        super.setUp()
        // Set to true to record new snapshots, false for testing
        // isRecording = true
    }

    // MARK: - CryType View Tests

    func testCryTypeIcons_AllTypes() {
        for cryType in CryType.allCases {
            let view = Image(systemName: cryType.icon)
                .font(.largeTitle)
                .foregroundColor(.accentColor)
                .frame(width: 100, height: 100)

            assertSnapshot(
                of: hostingController(for: view),
                as: .image(size: CGSize(width: 100, height: 100)),
                named: "cryType_\(cryType.rawValue)"
            )
        }
    }

    // MARK: - Button Style Tests

    func testPrimaryButtonStyle() {
        let view = Button("Play Now") {}
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 200, height: 60)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 250, height: 100)),
            named: "primaryButton"
        )
    }

    func testSecondaryButtonStyle() {
        let view = Button("Settings") {}
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: 200, height: 60)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 250, height: 100)),
            named: "secondaryButton"
        )
    }

    // MARK: - Color Palette Tests

    func testAppColorPalette() {
        let colors: [(String, Color)] = [
            ("Primary", AppColors.primary),
            ("Secondary", AppColors.secondary),
            ("Background", AppColors.background),
            ("Surface", AppColors.surface),
            ("Text Primary", AppColors.textPrimary),
            ("Text Secondary", AppColors.textSecondary),
        ]

        for (name, color) in colors {
            let view = Rectangle()
                .fill(color)
                .frame(width: 100, height: 100)

            assertSnapshot(
                of: hostingController(for: view),
                as: .image(size: CGSize(width: 100, height: 100)),
                named: "color_\(name.replacingOccurrences(of: " ", with: "_"))"
            )
        }
    }

    // MARK: - Component Snapshot Tests

    func testLoadingSkeletonView() {
        let view = SkeletonLoadingView()
            .frame(width: 300, height: 100)
            .padding()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 350, height: 150)),
            named: "skeleton_loading"
        )
    }

    func testEmptyStateView() {
        let view = EmptyStateView(
            icon: "music.note",
            title: "No Tracks",
            message: "Your library is empty"
        )
        .frame(width: 300, height: 200)

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 300, height: 200)),
            named: "empty_state"
        )
    }

    // MARK: - Dark Mode Tests

    func testPrimaryButtonStyle_DarkMode() {
        let view = Button("Play Now") {}
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 200, height: 60)
            .padding()
            .background(Color.black)
            .environment(\.colorScheme, .dark)

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 250, height: 100)),
            named: "primaryButton_darkMode"
        )
    }

    // MARK: - Device Size Tests

    func testResponsiveLayout_iPhone_SE() {
        let view = createSampleView()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhoneSe),
            named: "responsive_iPhoneSE"
        )
    }

    func testResponsiveLayout_iPhone_15() {
        let view = createSampleView()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhone13), // Using iPhone 13 config as proxy
            named: "responsive_iPhone15"
        )
    }

    func testResponsiveLayout_iPhone_15_ProMax() {
        let view = createSampleView()

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(on: .iPhone13ProMax),
            named: "responsive_iPhone15ProMax"
        )
    }

    // MARK: - Accessibility Tests

    func testLargeTextAccessibility() {
        let view = Text("Baby in Car")
            .font(.largeTitle)
            .padding()
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

        assertSnapshot(
            of: hostingController(for: view),
            as: .image(size: CGSize(width: 400, height: 150)),
            named: "largeText_accessibility"
        )
    }

    // MARK: - Helpers

    private func hostingController<V: View>(for view: V) -> UIHostingController<V> {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = UIScreen.main.bounds
        return controller
    }

    private func createSampleView() -> some View {
        VStack(spacing: 16) {
            Text("Baby in Car")
                .font(.title)
            Text("Soothing sounds for your little one")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Start Monitoring") {}
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

// MARK: - Placeholder Types for Compilation
// These should be replaced with actual types from the app

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(AppColors.surface)
            .foregroundColor(AppColors.primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.primary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SkeletonLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 16)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Placeholder for app colors
enum AppColors {
    static let primary = Color.blue
    static let secondary = Color.purple
    static let background = Color(UIColor.systemBackground)
    static let surface = Color(UIColor.secondarySystemBackground)
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
}
