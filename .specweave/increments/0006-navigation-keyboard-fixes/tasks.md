# Tasks: Navigation, Safe Area & Keyboard Handling Fixes

## T-001: Create global keyboard dismiss extension
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [x] completed
**Test**: Given any view with text input → When user taps outside input → Then keyboard dismisses

Already exists in `BabyInCarApp/Utilities/KeyboardHelper.swift`:
- `dismissKeyboardOnTap()` - tap gesture to dismiss
- `dismissKeyboardOnBackgroundTap()` - background tap without interfering with other gestures
- `keyboardDoneButton()` - keyboard toolbar with Done button
- `KeyboardAwareScrollView` - ScrollView with automatic keyboard adjustment
- `dismissKeyboardOnDrag()` - dismiss on scroll gesture

---

## T-002: Fix SearchView keyboard handling
**User Story**: US-003, US-004 | **Satisfies ACs**: AC-US3-04, AC-US4-01, AC-US4-04 | **Status**: [x] completed
**Test**: Given SearchView → When keyboard appears → Then search field remains visible AND keyboard can be dismissed

Added:
- `.scrollDismissesKeyboard(.interactively)` to ScrollView
- `.onTapGesture { isSearchFocused = false }` for background tap dismiss
- Keyboard toolbar with Done button using ToolbarItemGroup(placement: .keyboard)

---

## T-003: Fix LibraryView keyboard Done button
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03, AC-US4-04 | **Status**: [x] completed
**Test**: Given LibraryView search → When keyboard appears → Then Done button is visible in keyboard toolbar

Verified - Already has:
- `.scrollDismissesKeyboard(.interactively)` on ScrollView (line 67)
- Keyboard toolbar with Done button (lines 79-86)
- `@FocusState` for focus management

---

## T-004: Fix PlayerView close button and safe areas
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US2-01, AC-US2-03 | **Status**: [x] completed
**Test**: Given PlayerView as sheet → When displayed → Then close button is visible in safe area AND bottom controls don't overlap home indicator

Verified - Already has:
- Frosted glass dismiss button (chevron.down) in premiumHeader
- `geometry.safeAreaInsets.top` used for header padding
- Bottom content uses `max(geometry.safeAreaInsets.bottom, 20)` for safe area
- `.ignoresSafeArea()` only on background, not content

---

## T-005: Fix EmergencyModeView safe areas
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-03 | **Status**: [x] completed
**Test**: Given EmergencyModeView as fullScreenCover → When displayed → Then buttons don't overlap status bar or home indicator

Fixed:
- Added GeometryReader for safe area inset access
- Added `Color.clear.frame(height: max(geometry.safeAreaInsets.top, 20))` for top safe area
- Updated bottom padding to `max(geometry.safeAreaInsets.bottom, 20) + 20`
- `.ignoresSafeArea()` only applies to background gradient

---

## T-006: Fix CryDetectionSettingsView keyboard
**User Story**: US-003, US-004 | **Satisfies ACs**: AC-US3-01, AC-US4-01 | **Status**: [x] completed
**Test**: Given CryDetectionSettingsView with slider → When interacting → Then form scrolls properly

Verified:
- Uses Form which has built-in keyboard handling
- NavigationView with Done button in toolbar
- No TextField inputs (only Toggle and Slider) - no keyboard needed currently

---

## T-007: Fix VoiceControlSheet safe areas
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-03 | **Status**: [x] completed
**Test**: Given VoiceControlSheet → When displayed → Then content respects safe areas

Verified:
- NavigationView provides safe area automatically
- Done button in toolbar at cancellationAction placement
- Bottom button has `.padding(.bottom, 32)` for home indicator
- Uses VStack with Spacer() for proper content layout

---

## T-008: Fix OnboardingView keyboard handling
**User Story**: US-003, US-004 | **Satisfies ACs**: AC-US3-01, AC-US4-01, AC-US4-03 | **Status**: [x] completed
**Test**: Given OnboardingView with baby name input → When keyboard appears → Then input field is visible AND keyboard can be dismissed

Already implemented in BabyInfoPage:
- `.scrollDismissesKeyboard(.interactively)` on ScrollView (line 435)
- `.onTapGesture { isNameFieldFocused = false }` for background tap (lines 436-438)
- Keyboard toolbar with Done button (lines 445-454)
- `@FocusState` for focus management (line 333)
- Extra bottom spacer for keyboard clearance (line 432)

---

## T-009: Verify all NavigationStack views have back navigation
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03 | **Status**: [x] completed
**Test**: Given any detail view in NavigationStack → When user swipes from left edge → Then navigation goes back

Verified - SwiftUI NavigationStack/NavigationView provides swipe-to-go-back by default:
- LibraryView uses NavigationStack - supports swipe-back
- ProfileView uses NavigationStack with NavigationLink destinations
- TaxonomyBrowseView embedded in NavigationStack - inherits swipe-back
- All NavigationLink destinations automatically get back buttons and swipe-back

---

## T-010: Verify all sheet views have close buttons
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-04 | **Status**: [x] completed
**Test**: Given any sheet view → When displayed → Then close/Done button is visible with 44pt tap target

All sheet views verified:
- SearchView ✓ (has Done button in toolbar)
- EditBabySheet ✓ (has Cancel/Save in toolbar)
- LanguageSelectionSheet ✓ (has Cancel/Save in toolbar)
- CryDetectionSettingsView ✓ (has Done in toolbar)
- CryDetectionHistoryView ✓ (has Done in toolbar)
- SubscriptionView ✓ (has Close button in toolbar - lines 338-344)
- VoiceControlSheet ✓ (has Done button in toolbar)
- DatePickerSheet ✓ (has Done in toolbar)
- VoiceInputSheet ✓ (has Cancel/Confirm in toolbar)
- PlayerView ✓ (has chevron.down dismiss button with frosted glass)
- TrackDownloadView - component view, not a sheet (used inline)

---

## Progress Summary
- [x] T-001: Create global keyboard dismiss extension
- [x] T-002: Fix SearchView keyboard handling
- [x] T-003: Fix LibraryView keyboard Done button
- [x] T-004: Fix PlayerView close button and safe areas
- [x] T-005: Fix EmergencyModeView safe areas
- [x] T-006: Fix CryDetectionSettingsView keyboard
- [x] T-007: Fix VoiceControlSheet safe areas
- [x] T-008: Fix OnboardingView keyboard handling
- [x] T-009: Verify all NavigationStack views have back navigation
- [x] T-010: Verify all sheet views have close buttons
