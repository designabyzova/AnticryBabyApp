import SwiftUI

/// Premium Spotify-level filter chip with smart multi-select and haptic feedback
struct FilterChipView: View {
    let tag: FilterTag
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 6) {
                // Icon
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }

                // Display name
                Text(tag.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))

                // Track count badge
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? chipBackgroundColor : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.3) : Color(.systemGray5))
                        )
                }

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(chipBackground)
                    .shadow(
                        color: isSelected ? chipBackgroundColor.opacity(0.3) : .clear,
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 1 : 2
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }

    private var chipBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [chipBackgroundColor, chipBackgroundColor.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color(.systemGray6))
        }
    }

    private var chipBackgroundColor: Color {
        tag.color ?? tag.type.color
    }
}

/// Horizontal scrollable filter chip bar with smart grouping
struct FilterChipBar: View {
    let tags: [FilterTag]
    let selectedTags: Set<FilterTag>
    let trackCounts: [FilterTag: Int]
    let onTagToggle: (FilterTag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tags) { tag in
                    FilterChipView(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        count: trackCounts[tag],
                        action: { onTagToggle(tag) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

/// Grouped filter sections by tag type (Spotify-style)
struct GroupedFilterView: View {
    let tagsByType: [FilterTagType: [FilterTag]]
    let selectedTags: Set<FilterTag>
    let trackCounts: [FilterTag: Int]
    let onTagToggle: (FilterTag) -> Void

    private let orderedTypes: [FilterTagType] = [
        .category,
        .subcategory,
        .instrument,
        .mood,
        .tempo,
        .theme,
        .language,
        .ageRange,
        .duration,
        .calmingLevel
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(orderedTypes.filter { tagsByType[$0] != nil }, id: \.self) { type in
                if let tags = tagsByType[type], !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        // Section header
                        HStack {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(type.color)

                            Text(type.displayName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)

                            Spacer()

                            // Active filter count for this type
                            let activeCount = tags.filter { selectedTags.contains($0) }.count
                            if activeCount > 0 {
                                Text("\(activeCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(type.color))
                            }
                        }
                        .padding(.horizontal, 20)

                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(tags) { tag in
                                    FilterChipView(
                                        tag: tag,
                                        isSelected: selectedTags.contains(tag),
                                        count: trackCounts[tag],
                                        action: { onTagToggle(tag) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

/// Smart filter reset button with undo capability
struct FilterResetButton: View {
    let activeFilterCount: Int
    let onReset: () -> Void
    let onUndo: (() -> Void)?

    @State private var showUndo = false

    var body: some View {
        HStack(spacing: 12) {
            // Reset all button
            if activeFilterCount > 0 {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        onReset()
                        if onUndo != nil {
                            showUndo = true
                        }
                    }

                    // Auto-hide undo after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            showUndo = false
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Clear \(activeFilterCount) filter\(activeFilterCount > 1 ? "s" : "")")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.red)
                            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Undo button (appears after reset)
            if showUndo, let undoAction = onUndo {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    withAnimation {
                        undoAction()
                        showUndo = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Undo")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showUndo)
    }
}

/// Filter preset card (Spotify-style Quick Picks)
struct FilterPresetCard: View {
    let preset: FilterPreset
    let isLocked: Bool
    let onApply: () -> Void

    var body: some View {
        Button(action: {
            guard !isLocked else { return }
            HapticManager.shared.impact(style: .medium)
            onApply()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon and lock
                HStack {
                    Image(systemName: preset.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Name
                Text(preset.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Description
                Text(preset.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)

                // Tag count
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 11))
                    Text("\(preset.tags.count) filters")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .frame(width: 160, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isLocked
                                ? [Color.gray, Color.gray.opacity(0.8)]
                                : [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Filter preset horizontal scroll section
struct FilterPresetSection: View {
    let presets: [FilterPreset]
    let isPremiumUser: Bool
    let onPresetApply: (FilterPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Picks")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(presets) { preset in
                        FilterPresetCard(
                            preset: preset,
                            isLocked: preset.isPremium && !isPremiumUser,
                            onApply: { onPresetApply(preset) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Preview

#Preview("Filter Chips") {
    VStack(spacing: 20) {
        FilterChipView(
            tag: FilterTag(
                type: .category,
                value: "classical",
                displayName: "Classical Music",
                icon: "music.note",
                color: .blue
            ),
            isSelected: false,
            count: 24,
            action: {}
        )

        FilterChipView(
            tag: FilterTag(
                type: .instrument,
                value: "piano",
                displayName: "Piano",
                icon: "pianokeys",
                color: .orange
            ),
            isSelected: true,
            count: 12,
            action: {}
        )

        FilterResetButton(
            activeFilterCount: 3,
            onReset: {},
            onUndo: {}
        )
    }
    .padding()
}

#Preview("Filter Preset") {
    FilterPresetSection(
        presets: FilterPreset.defaults,
        isPremiumUser: false,
        onPresetApply: { _ in }
    )
}
