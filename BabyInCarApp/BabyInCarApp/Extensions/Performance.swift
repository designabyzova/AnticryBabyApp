//
//  Performance.swift
//  BabyInCarApp
//
//  Performance optimizations for smooth 60fps animations on all devices
//

import SwiftUI
import UIKit

// MARK: - Performance Manager

/// Manages performance settings and optimizations
class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()

    /// Whether to use simplified animations on older devices
    @Published var useSimplifiedAnimations: Bool = false

    /// Whether to reduce shadow complexity
    @Published var useSimplifiedShadows: Bool = false

    /// Whether to reduce blur effects
    @Published var reduceBlurEffects: Bool = false

    /// Current device performance tier
    let deviceTier: DeviceTier

    private init() {
        deviceTier = DeviceTier.current
        configureForDevice()
    }

    private func configureForDevice() {
        switch deviceTier {
        case .low:
            useSimplifiedAnimations = true
            useSimplifiedShadows = true
            reduceBlurEffects = true
        case .medium:
            useSimplifiedAnimations = false
            useSimplifiedShadows = true
            reduceBlurEffects = false
        case .high:
            useSimplifiedAnimations = false
            useSimplifiedShadows = false
            reduceBlurEffects = false
        }
    }
}

// MARK: - Device Performance Tier

enum DeviceTier {
    case low    // iPhone 8 and earlier, older iPads
    case medium // iPhone X - iPhone 12
    case high   // iPhone 13+ and M1+ devices

    static var current: DeviceTier {
        let device = UIDevice.current
        let systemVersion = (device.systemVersion as NSString).floatValue

        // Check processor info
        var sysinfo = utsname()
        uname(&sysinfo)
        let machineIdentifier = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }

        // iPhone models (simplified check)
        if machineIdentifier.contains("iPhone") {
            // Extract model number (e.g., "iPhone14,5" -> 14)
            if let modelNumber = extractModelNumber(from: machineIdentifier) {
                if modelNumber >= 14 {
                    return .high  // iPhone 13+
                } else if modelNumber >= 10 {
                    return .medium  // iPhone X - iPhone 12
                }
            }
        }

        // Fallback based on iOS version and RAM
        if systemVersion >= 16.0 {
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let memoryGB = Double(totalMemory) / 1_073_741_824 // Convert to GB

            if memoryGB >= 6.0 {
                return .high
            } else if memoryGB >= 4.0 {
                return .medium
            }
        }

        return .low
    }

    private static func extractModelNumber(from identifier: String) -> Int? {
        let pattern = "iPhone(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: identifier, range: NSRange(identifier.startIndex..., in: identifier)),
              let range = Range(match.range(at: 1), in: identifier) else {
            return nil
        }
        return Int(identifier[range])
    }
}

// MARK: - Performance-Optimized View Modifiers

extension View {
    /// Apply shadows with performance optimization
    func performantShadow(
        color: Color = .black.opacity(0.1),
        radius: CGFloat = 8,
        x: CGFloat = 0,
        y: CGFloat = 4
    ) -> some View {
        modifier(PerformantShadowModifier(color: color, radius: radius, x: x, y: y))
    }

    /// Apply blur with performance optimization
    func performantBlur(radius: CGFloat) -> some View {
        modifier(PerformantBlurModifier(radius: radius))
    }

    /// Lazy loading wrapper for heavy views
    func lazyLoad<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        LazyLoadingView(content: content)
    }

    /// Animation with performance consideration
    func performantAnimation<Value: Equatable>(
        _ animation: Animation? = .default,
        value: Value
    ) -> some View {
        modifier(PerformantAnimationModifier(animation: animation, value: value))
    }

    /// Draw into bitmap for complex views (use sparingly)
    func drawIntoLayer() -> some View {
        self.drawingGroup()
    }
}

// MARK: - Modifier Implementations

struct PerformantShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    @ObservedObject private var performanceManager = PerformanceManager.shared

    func body(content: Content) -> some View {
        if performanceManager.useSimplifiedShadows {
            // Simplified shadow: smaller radius, single shadow
            content
                .shadow(color: color.opacity(0.7), radius: max(2, radius * 0.3), x: x * 0.5, y: y * 0.5)
        } else {
            // Full quality shadow
            content
                .shadow(color: color, radius: radius, x: x, y: y)
        }
    }
}

struct PerformantBlurModifier: ViewModifier {
    let radius: CGFloat

    @ObservedObject private var performanceManager = PerformanceManager.shared

    func body(content: Content) -> some View {
        if performanceManager.reduceBlurEffects {
            // Reduced blur or opacity fallback
            content
                .blur(radius: max(1, radius * 0.3))
        } else {
            content
                .blur(radius: radius)
        }
    }
}

struct PerformantAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation?
    let value: Value

    @ObservedObject private var performanceManager = PerformanceManager.shared

    func body(content: Content) -> some View {
        if performanceManager.useSimplifiedAnimations {
            // Simplified or no animation
            content
                .animation(.linear(duration: 0.15), value: value)
        } else {
            content
                .animation(animation, value: value)
        }
    }
}

// MARK: - Lazy Loading View

struct LazyLoadingView<Content: View>: View {
    let content: () -> Content

    @State private var hasAppeared = false

    var body: some View {
        Group {
            if hasAppeared {
                content()
            } else {
                Color.clear
                    .onAppear {
                        hasAppeared = true
                    }
            }
        }
    }
}

// MARK: - Image Optimization

extension Image {
    /// Create optimized image with proper scaling
    static func optimized(
        named name: String,
        renderingMode: TemplateRenderingMode = .original
    ) -> some View {
        Image(name)
            .resizable()
            .renderingMode(renderingMode)
            .interpolation(.medium)
    }

    /// System image with optimized rendering
    static func optimizedSystemImage(
        _ systemName: String,
        scale: Image.Scale = .medium
    ) -> some View {
        Image(systemName: systemName)
            .imageScale(scale)
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Memory-Efficient List

/// A list that efficiently handles large datasets
struct EfficientList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(data) { item in
                content(item)
            }
        }
    }
}

// MARK: - Debounced State Updates

/// Property wrapper for debouncing rapid state updates
@propertyWrapper
struct Debounced<Value>: DynamicProperty {
    @State private var value: Value
    @State private var debouncedValue: Value

    private let delay: TimeInterval
    private var debounceTask: DispatchWorkItem?

    init(wrappedValue: Value, delay: TimeInterval = 0.3) {
        self._value = State(initialValue: wrappedValue)
        self._debouncedValue = State(initialValue: wrappedValue)
        self.delay = delay
    }

    var wrappedValue: Value {
        get { debouncedValue }
        nonmutating set {
            value = newValue
            debounce()
        }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { value },
            set: { newValue in
                value = newValue
                debounce()
            }
        )
    }

    private func debounce() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            debouncedValue = value
        }
    }
}

// MARK: - Animation Frame Rate Limiter

/// Limits animation updates to prevent excessive redraws
struct FrameRateLimiter {
    private let targetFPS: Double
    private var lastUpdate: Date = Date()

    init(targetFPS: Double = 60) {
        self.targetFPS = targetFPS
    }

    mutating func shouldUpdate() -> Bool {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdate)
        let targetInterval = 1.0 / targetFPS

        if elapsed >= targetInterval {
            lastUpdate = now
            return true
        }
        return false
    }
}

// MARK: - Cached Async Image

/// Image that caches loaded content
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private static var cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
                    .resizable()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        // Check cache first
        if let cached = Self.cache.object(forKey: url.absoluteString as NSString) {
            loadedImage = cached
            return
        }

        isLoading = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    Self.cache.setObject(image, forKey: url.absoluteString as NSString)
                    await MainActor.run {
                        loadedImage = image
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Performance Monitoring View Modifier

struct PerformanceMonitor: ViewModifier {
    let label: String
    @State private var renderCount = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                renderCount += 1
                #if DEBUG
                print("[\(label)] Render count: \(renderCount)")
                #endif
            }
    }
}

extension View {
    /// Monitor view render performance (debug only)
    func monitorPerformance(label: String) -> some View {
        #if DEBUG
        return modifier(PerformanceMonitor(label: label))
        #else
        return self
        #endif
    }
}

// MARK: - Previews

#Preview("Performance Settings") {
    VStack(spacing: 20) {
        Text("Device Tier: \(String(describing: DeviceTier.current))")
            .font(.headline)

        Text("Simplified Animations: \(PerformanceManager.shared.useSimplifiedAnimations ? "Yes" : "No")")
        Text("Simplified Shadows: \(PerformanceManager.shared.useSimplifiedShadows ? "Yes" : "No")")
        Text("Reduce Blur: \(PerformanceManager.shared.reduceBlurEffects ? "Yes" : "No")")

        RoundedRectangle(cornerRadius: 16)
            .fill(Color.appPrimary)
            .frame(height: 100)
            .performantShadow(color: .appPrimary.opacity(0.4), radius: 20, y: 10)
            .padding()
    }
    .padding()
}
