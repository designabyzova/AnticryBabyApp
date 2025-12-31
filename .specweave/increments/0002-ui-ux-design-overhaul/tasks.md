# Tasks - UI/UX Design Overhaul

## Phase 1: Brand Identity & Foundation

### T-001: Create App Logo and Icon Set
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US1-04 | **Status**: [x] completed
**Test**: Given the app icon assets exist → When displayed at all sizes → Then icon is clear and recognizable

Create a beautiful app icon featuring:
- Sleeping baby face with peaceful expression
- Subtle sound wave or musical note elements
- Soft, dreamy color palette (lavender, soft blue, cream)
- Generate all required sizes for iOS/macOS
- Optional dark variant

### T-002: Implement Animated Splash Screen
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**Test**: Given app launches → When splash displays → Then logo animates smoothly before transitioning to main UI

Create LaunchScreen.storyboard and custom splash animation with:
- Logo fade-in and scale animation
- Soft gradient background
- Smooth transition to onboarding/home

### T-003: Implement New Color System
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05 | **Status**: [x] completed
**Test**: Given color tokens are defined → When used throughout app → Then colors are consistent and harmonious

Update Colors.swift with new palette:
- Primary: Soft Lavender, Dreamy Blue, Warm Cream
- Secondary: Gentle Mint, Soft Coral, Cloud White
- Dark mode variants
- Gradient definitions

### T-004: Update Typography System
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-04 | **Status**: [x] completed
**Test**: Given text elements → When rendered → Then typography is consistent and readable

Create Typography.swift with:
- SF Pro Rounded font definitions
- Type scale (largeTitle, headline, body, caption, etc.)
- Line heights and letter spacing
- Ensure 44pt minimum touch targets

## Phase 2: Component Library

### T-005: Create Custom Category Icons
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed
**Test**: Given category displayed → When icon shown → Then custom themed icon appears (not generic SF Symbol)

Design and implement custom icons for:
- Classical Music (elegant piano/violin)
- Fairy Tales (open book with stars)
- White Noise (soft waves)
- Nature Sounds (leaf/cloud)
- Instrumental (harp/bells)
- Children's Songs (music box)
- Podcasts (microphone with hearts)

### T-006: Create Neumorphic Card Component
**User Story**: US-005 | **Satisfies ACs**: AC-US5-03 | **Status**: [x] completed
**Test**: Given card displayed → When viewed → Then card has subtle depth and soft shadows

Create NeuCard view modifier with:
- Soft inner/outer shadows
- Subtle border highlight
- Light/dark mode support
- Configurable corner radius

### T-007: Create Animated Button Components
**User Story**: US-005 | **Satisfies ACs**: AC-US5-05 | **Status**: [x] completed
**Test**: Given button tapped → When animation plays → Then scale/haptic feedback occurs smoothly

Create button styles:
- PrimaryButtonStyle (scale + haptic)
- SecondaryButtonStyle (subtle glow)
- IconButtonStyle (rotation/morph effect)
- EmergencyButtonStyle (pulsing glow)

### T-008: Create Skeleton Loading Views
**User Story**: US-009 | **Satisfies ACs**: AC-US9-01, AC-US9-03 | **Status**: [x] completed
**Test**: Given loading state → When skeleton shown → Then shimmer animation is smooth

Create loading components:
- SkeletonView with shimmer effect
- TrackCardSkeleton
- PlaylistCardSkeleton
- CategoryCardSkeleton

### T-009: Create Empty State Views
**User Story**: US-009 | **Satisfies ACs**: AC-US9-02, AC-US9-04 | **Status**: [x] completed
**Test**: Given empty content → When displayed → Then friendly illustration and suggestion shown

Create empty state illustrations:
- NoFavoritesView (sleeping baby with hearts)
- NoPlaylistsView (music notes floating)
- NoDownloadsView (cloud with arrow)
- Each with action button

## Phase 3: Screen Redesigns

### T-010: Redesign Onboarding Flow
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03, AC-US4-04 | **Status**: [x] completed
**Test**: Given user on onboarding → When navigating → Then animations are smooth and delightful

Update OnboardingView.swift:
- Animated illustrations per page
- Parallax background effects
- Playful progress indicator
- Personalized welcome animation

### T-011: Redesign Home Screen
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01, AC-US5-02, AC-US5-04 | **Status**: [x] completed
**Test**: Given user on home → When viewing → Then hero card and emergency button are premium-looking

Update HomeView.swift:
- Time-aware greeting hero card
- Pulsing glow emergency button
- Parallax scroll effects
- Category cards with new styling

### T-012: Redesign Player View
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01, AC-US6-02, AC-US6-03, AC-US6-04, AC-US6-05 | **Status**: [x] completed
**Test**: Given player open → When playing → Then animations and visualizations are smooth

Update PlayerView.swift:
- Breathing artwork animation
- Frosted glass controls
- Progress bar with haptics
- Optional waveform visualization
- Gesture controls

### T-013: Redesign Mini Player
**User Story**: US-007 | **Satisfies ACs**: AC-US7-01, AC-US7-02, AC-US7-03, AC-US7-04 | **Status**: [x] completed
**Test**: Given mini player visible → When interacting → Then animations are fluid

Update MiniPlayerView in ContentView.swift:
- Floating pill design with blur
- Progress ring animation
- Expand/collapse transition
- Swipe gestures

### T-014: Redesign Tab Bar
**User Story**: US-008 | **Satisfies ACs**: AC-US8-01, AC-US8-02, AC-US8-03, AC-US8-04 | **Status**: [x] completed
**Test**: Given tab bar → When switching tabs → Then indicator animates smoothly

Update CustomTabBar in ContentView.swift:
- Animated selection indicator (sliding dot/line)
- Icon scale/morph on selection
- Subtle bounce on tap
- Clear active state

## Phase 4: Polish & Accessibility

### T-015: Implement Dark Mode Refinements
**User Story**: US-010 | **Satisfies ACs**: AC-US10-02 | **Status**: [x] completed
**Test**: Given dark mode → When viewing at night → Then colors are muted and eye-friendly

Update all views for dark mode:
- Reduced blue light in dark theme
- Appropriate contrast ratios
- Test all screens in dark mode

### T-016: Add Accessibility Support
**User Story**: US-010 | **Satisfies ACs**: AC-US10-01, AC-US10-03, AC-US10-04 | **Status**: [x] completed
**Test**: Given accessibility features enabled → When using app → Then app is fully accessible

Add accessibility:
- VoiceOver labels for all buttons
- accessibilityHint for complex controls
- Reduce Motion support (simplified animations)
- Contrast compliance check

### T-017: Add Micro-Interactions Polish
**User Story**: US-005, US-006 | **Satisfies ACs**: AC-US5-05, AC-US6-03 | **Status**: [x] completed
**Test**: Given user interactions → When tapping/swiping → Then feedback is satisfying

Polish all interactions:
- Haptic feedback on key actions
- Button press animations
- Card highlight effects
- Transition refinements

### T-018: Performance Optimization
**User Story**: All | **Satisfies ACs**: All | **Status**: [x] completed
**Test**: Given animations running → When profiled → Then consistent 60fps on iPhone 8+

Optimize for performance:
- Profile animations
- Lazy load heavy views
- Optimize image assets
- Test on older devices
