//
//  SkeletonLoading.swift
//  BabyInCarApp
//
//  Shimmer skeleton loading views for smooth loading states
//

import SwiftUI

// MARK: - Shimmer Effect

/// Animated shimmer gradient for skeleton loading
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.appTextTertiary.opacity(0.1), location: 0),
                .init(color: Color.appTextTertiary.opacity(0.3), location: 0.5),
                .init(color: Color.appTextTertiary.opacity(0.1), location: 1)
            ]),
            startPoint: .init(x: phase - 1, y: 0),
            endPoint: .init(x: phase, y: 0)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}

// MARK: - Skeleton Shape

/// Base skeleton shape with shimmer effect
struct SkeletonShape: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = DesignTokens.radiusS

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.appTextTertiary.opacity(0.15))
            .frame(width: width, height: height)
            .overlay(
                ShimmerView()
                    .mask(RoundedRectangle(cornerRadius: cornerRadius))
            )
    }
}

// MARK: - Skeleton Views

/// Skeleton for track card
struct TrackCardSkeleton: View {
    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Album art
            SkeletonShape(width: 56, height: 56, cornerRadius: DesignTokens.radiusS)

            // Text lines
            VStack(alignment: .leading, spacing: 8) {
                SkeletonShape(width: 140, height: 16)
                SkeletonShape(width: 100, height: 12)
            }

            Spacer()

            // Heart icon
            SkeletonShape(width: 24, height: 24, cornerRadius: 12)
        }
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
        )
    }
}

/// Skeleton for category card
struct CategoryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            // Icon circle
            SkeletonShape(width: 48, height: 48, cornerRadius: 24)

            Spacer()

            // Text
            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape(width: 80, height: 14)
                SkeletonShape(width: 50, height: 10)
            }
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                .fill(Color.appCardBackground)
        )
    }
}

/// Skeleton for quick pick card
struct QuickPickCardSkeleton: View {
    var body: some View {
        VStack(spacing: DesignTokens.spacingS) {
            SkeletonShape(height: 80, cornerRadius: DesignTokens.radiusM)

            VStack(spacing: 4) {
                SkeletonShape(width: 60, height: 12)
                SkeletonShape(width: 40, height: 10)
            }
        }
    }
}

/// Skeleton for playlist card
struct PlaylistCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            // Cover image
            SkeletonShape(height: 120, cornerRadius: DesignTokens.radiusM)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(width: 100, height: 16)
                SkeletonShape(width: 70, height: 12)
            }
        }
    }
}

/// Skeleton for player view artwork
struct PlayerArtworkSkeleton: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appTextTertiary.opacity(0.1))
                .frame(width: 260, height: 260)
                .overlay(ShimmerView().mask(Circle()))

            Circle()
                .fill(Color.appCardBackground)
                .frame(width: 180, height: 180)
                .overlay(ShimmerView().mask(Circle()))
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.02
            }
        }
    }
}

/// Full screen skeleton for loading state
struct FullScreenSkeleton: View {
    var body: some View {
        VStack(spacing: DesignTokens.spacingL) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape(width: 120, height: 28)
                    SkeletonShape(width: 80, height: 16)
                }

                Spacer()

                SkeletonShape(width: 44, height: 44, cornerRadius: 22)
            }
            .padding(.horizontal, 20)

            // Emergency button placeholder
            SkeletonShape(height: 60, cornerRadius: DesignTokens.radiusL)
                .padding(.horizontal, 20)

            // Section title
            HStack {
                SkeletonShape(width: 140, height: 18)
                Spacer()
            }
            .padding(.horizontal, 20)

            // Quick picks grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    QuickPickCardSkeleton()
                }
            }
            .padding(.horizontal, 20)

            // Categories section
            HStack {
                SkeletonShape(width: 100, height: 18)
                Spacer()
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    CategoryCardSkeleton()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.appBackground)
    }
}

// MARK: - Loading State Modifier

/// View modifier to show skeleton while loading
struct SkeletonLoadingModifier<Skeleton: View>: ViewModifier {
    var isLoading: Bool
    var skeleton: Skeleton

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                skeleton
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

extension View {
    /// Show skeleton loading state
    func skeleton<S: View>(isLoading: Bool, @ViewBuilder skeleton: () -> S) -> some View {
        modifier(SkeletonLoadingModifier(isLoading: isLoading, skeleton: skeleton()))
    }
}

// MARK: - Preview

#Preview("Skeleton Loading") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Track Card Skeleton")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TrackCardSkeleton()
            TrackCardSkeleton()
            TrackCardSkeleton()

            Text("Category Card Skeleton")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CategoryCardSkeleton()
                CategoryCardSkeleton()
            }

            Text("Quick Pick Skeleton")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickPickCardSkeleton()
                QuickPickCardSkeleton()
                QuickPickCardSkeleton()
            }

            Text("Player Artwork Skeleton")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            PlayerArtworkSkeleton()
        }
        .padding()
    }
    .background(Color.appBackground)
}
