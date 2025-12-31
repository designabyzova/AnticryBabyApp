//
//  Typography.swift
//  BabyInCarApp
//
//  Typography system with SF Pro Rounded for a friendly, approachable feel
//  Optimized for readability and accessibility
//

import SwiftUI

// MARK: - Typography Tokens

enum Typography {
    // MARK: - Font Sizes
    enum Size {
        static let caption2: CGFloat = 10
        static let caption: CGFloat = 12
        static let footnote: CGFloat = 13
        static let subheadline: CGFloat = 14
        static let body: CGFloat = 16
        static let callout: CGFloat = 17
        static let headline: CGFloat = 18
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title: CGFloat = 28
        static let largeTitle: CGFloat = 34
        static let display: CGFloat = 44
    }

    // MARK: - Line Heights (multiplier)
    enum LineHeight {
        static let tight: CGFloat = 1.1
        static let normal: CGFloat = 1.3
        static let relaxed: CGFloat = 1.5
        static let loose: CGFloat = 1.7
    }

    // MARK: - Letter Spacing
    enum LetterSpacing {
        static let tight: CGFloat = -0.5
        static let normal: CGFloat = 0
        static let wide: CGFloat = 0.5
        static let extraWide: CGFloat = 1.0
    }
}

// MARK: - Font Extension

extension Font {
    // MARK: - Display & Headlines (SF Pro Rounded - Bold)

    /// Extra large display text for splash/hero (44pt)
    static let appDisplay = Font.system(size: Typography.Size.display, weight: .bold, design: .rounded)

    /// Large title for main headings (34pt)
    static let appLargeTitle = Font.system(size: Typography.Size.largeTitle, weight: .bold, design: .rounded)

    /// Title for section headers (28pt)
    static let appTitle = Font.system(size: Typography.Size.title, weight: .bold, design: .rounded)

    /// Title 2 for card headers (24pt)
    static let appTitle2 = Font.system(size: Typography.Size.title2, weight: .semibold, design: .rounded)

    /// Title 3 for list items (20pt)
    static let appTitle3 = Font.system(size: Typography.Size.title3, weight: .semibold, design: .rounded)

    /// Headline for emphasis (18pt)
    static let appHeadline = Font.system(size: Typography.Size.headline, weight: .semibold, design: .rounded)

    // MARK: - Body Text (SF Pro Rounded - Regular/Medium)

    /// Callout for prominent body (17pt)
    static let appCallout = Font.system(size: Typography.Size.callout, weight: .medium, design: .rounded)

    /// Standard body text (16pt)
    static let appBody = Font.system(size: Typography.Size.body, weight: .regular, design: .rounded)

    /// Body with medium weight
    static let appBodyMedium = Font.system(size: Typography.Size.body, weight: .medium, design: .rounded)

    /// Subheadline for secondary content (14pt)
    static let appSubheadline = Font.system(size: Typography.Size.subheadline, weight: .regular, design: .rounded)

    /// Subheadline with medium weight
    static let appSubheadlineMedium = Font.system(size: Typography.Size.subheadline, weight: .medium, design: .rounded)

    // MARK: - Small Text (SF Pro Rounded)

    /// Footnote for supporting text (13pt)
    static let appFootnote = Font.system(size: Typography.Size.footnote, weight: .regular, design: .rounded)

    /// Caption for labels (12pt)
    static let appCaption = Font.system(size: Typography.Size.caption, weight: .regular, design: .rounded)

    /// Caption with medium weight
    static let appCaptionMedium = Font.system(size: Typography.Size.caption, weight: .medium, design: .rounded)

    /// Tiny caption (10pt)
    static let appCaption2 = Font.system(size: Typography.Size.caption2, weight: .regular, design: .rounded)

    // MARK: - Special Styles

    /// Monospaced for timers/numbers
    static let appMono = Font.system(size: Typography.Size.body, weight: .medium, design: .monospaced)

    /// Tab bar label
    static let appTabLabel = Font.system(size: 10, weight: .medium, design: .rounded)

    /// Button text (primary)
    static let appButton = Font.system(size: Typography.Size.body, weight: .semibold, design: .rounded)

    /// Button text (secondary/small)
    static let appButtonSmall = Font.system(size: Typography.Size.subheadline, weight: .medium, design: .rounded)

    // MARK: - Flexible Sizing

    /// Create a custom rounded font
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Text Style Modifiers

extension View {
    /// Apply display text style
    func displayStyle() -> some View {
        self
            .font(.appDisplay)
            .foregroundColor(.appText)
            .lineSpacing(Typography.Size.display * (Typography.LineHeight.tight - 1))
    }

    /// Apply large title style
    func largeTitleStyle() -> some View {
        self
            .font(.appLargeTitle)
            .foregroundColor(.appText)
    }

    /// Apply title style
    func titleStyle() -> some View {
        self
            .font(.appTitle)
            .foregroundColor(.appText)
    }

    /// Apply headline style
    func headlineStyle() -> some View {
        self
            .font(.appHeadline)
            .foregroundColor(.appText)
    }

    /// Apply body style
    func bodyStyle() -> some View {
        self
            .font(.appBody)
            .foregroundColor(.appText)
            .lineSpacing(Typography.Size.body * (Typography.LineHeight.relaxed - 1))
    }

    /// Apply secondary text style
    func secondaryStyle() -> some View {
        self
            .font(.appSubheadline)
            .foregroundColor(.appTextSecondary)
    }

    /// Apply caption style
    func captionStyle() -> some View {
        self
            .font(.appCaption)
            .foregroundColor(.appTextSecondary)
    }

    /// Apply button text style
    func buttonTextStyle() -> some View {
        self
            .font(.appButton)
            .foregroundColor(.white)
    }
}

// MARK: - Custom Text Views

/// Styled text component with semantic meaning
struct AppText: View {
    enum Style {
        case display
        case largeTitle
        case title
        case title2
        case title3
        case headline
        case callout
        case body
        case bodyMedium
        case subheadline
        case footnote
        case caption
        case caption2

        var font: Font {
            switch self {
            case .display: return .appDisplay
            case .largeTitle: return .appLargeTitle
            case .title: return .appTitle
            case .title2: return .appTitle2
            case .title3: return .appTitle3
            case .headline: return .appHeadline
            case .callout: return .appCallout
            case .body: return .appBody
            case .bodyMedium: return .appBodyMedium
            case .subheadline: return .appSubheadline
            case .footnote: return .appFootnote
            case .caption: return .appCaption
            case .caption2: return .appCaption2
            }
        }

        var defaultColor: Color {
            switch self {
            case .display, .largeTitle, .title, .title2, .title3, .headline, .callout, .body, .bodyMedium:
                return .appText
            case .subheadline, .footnote, .caption, .caption2:
                return .appTextSecondary
            }
        }
    }

    let text: String
    let style: Style
    var color: Color?
    var lineLimit: Int?
    var alignment: TextAlignment = .leading

    init(_ text: String, style: Style = .body, color: Color? = nil, lineLimit: Int? = nil, alignment: TextAlignment = .leading) {
        self.text = text
        self.style = style
        self.color = color
        self.lineLimit = lineLimit
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundColor(color ?? style.defaultColor)
            .lineLimit(lineLimit)
            .multilineTextAlignment(alignment)
    }
}

// MARK: - Animated Number Display

/// Animated number for timers and counts
struct AnimatedNumberText: View {
    let value: Int
    let format: String

    @State private var displayValue: Int = 0

    init(_ value: Int, format: String = "%d") {
        self.value = value
        self.format = format
    }

    var body: some View {
        Text(String(format: format, displayValue))
            .font(.appMono)
            .foregroundColor(.appText)
            .onChange(of: value) { newValue in
                withAnimation(.spring(response: 0.3)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Time Display

/// Formatted time display (minutes:seconds)
struct TimeText: View {
    let seconds: TimeInterval

    var body: some View {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        HStack(spacing: 0) {
            Text(String(format: "%d", minutes))
                .font(.appMono)

            Text(":")
                .font(.appMono)

            Text(String(format: "%02d", secs))
                .font(.appMono)
        }
        .foregroundColor(.appText)
    }
}

// MARK: - Preview

#Preview("Typography Scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Display (44pt)")
                    .font(.appDisplay)

                Text("Large Title (34pt)")
                    .font(.appLargeTitle)

                Text("Title (28pt)")
                    .font(.appTitle)

                Text("Title 2 (24pt)")
                    .font(.appTitle2)

                Text("Title 3 (20pt)")
                    .font(.appTitle3)
            }

            Divider()

            Group {
                Text("Headline (18pt)")
                    .font(.appHeadline)

                Text("Callout (17pt)")
                    .font(.appCallout)

                Text("Body (16pt)")
                    .font(.appBody)

                Text("Subheadline (14pt)")
                    .font(.appSubheadline)
            }

            Divider()

            Group {
                Text("Footnote (13pt)")
                    .font(.appFootnote)

                Text("Caption (12pt)")
                    .font(.appCaption)

                Text("Caption 2 (10pt)")
                    .font(.appCaption2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("AppText Component Examples")
                    .font(.appHeadline)

                AppText("Display Style", style: .display)
                AppText("Title Style", style: .title)
                AppText("Body Style", style: .body)
                AppText("Caption Style", style: .caption)
            }
        }
        .padding()
    }
}
