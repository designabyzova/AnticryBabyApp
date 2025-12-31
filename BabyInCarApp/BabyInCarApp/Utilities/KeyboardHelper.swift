//
//  KeyboardHelper.swift
//  BabyInCarApp
//
//  Keyboard handling utilities for dismissing keyboard and managing focus
//

import SwiftUI
import Combine

// MARK: - Keyboard Dismissal Extension
extension View {
    /// Adds a tap gesture to dismiss the keyboard
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    /// Adds a background tap gesture to dismiss keyboard without interfering with other gestures
    func dismissKeyboardOnBackgroundTap() -> some View {
        self.background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
        )
    }

    /// Hide keyboard programmatically
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Adds a keyboard toolbar with a Done button
    func keyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appPrimary)
            }
        }
    }
}

// MARK: - Keyboard Dismissing View Modifier
struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { _ in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
    }
}

extension View {
    /// Dismiss keyboard on scroll/drag gesture
    func dismissKeyboardOnDrag() -> some View {
        modifier(DismissKeyboardModifier())
    }
}

// MARK: - Keyboard-Aware ScrollView
struct KeyboardAwareScrollView<Content: View>: View {
    let content: Content
    @State private var keyboardHeight: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(.bottom, keyboardHeight)
        }
        .scrollDismissesKeyboard(.interactively)
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = height
            }
        }
    }
}

// MARK: - Keyboard Height Publisher
extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }

        return willShow.merge(with: willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - Safe Area Aware View Modifier
struct SafeAreaAwareModifier: ViewModifier {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
    }
}

// MARK: - SafeArea Insets Environment Key
private struct SafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

// MARK: - SafeArea Reader View
struct SafeAreaReader<Content: View>: View {
    let content: (EdgeInsets) -> Content

    var body: some View {
        GeometryReader { geometry in
            content(geometry.safeAreaInsets)
        }
    }
}

// MARK: - Keyboard Responsive TextField
struct KeyboardResponsiveTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var onSubmit: (() -> Void)?

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .onSubmit {
                onSubmit?()
            }
            .submitLabel(.done)
    }
}
