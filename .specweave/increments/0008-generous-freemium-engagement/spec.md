# FS-008: Generous Freemium & Engagement-First Monetization

## Philosophy

**"Let them fall in love before asking for money."**

The app's magic is in cry detection + personalized soothing. If users never experience this, they'll never convert. Our strategy:

1. **Generous free tier** - Full cry detection, limited content
2. **Value-first onboarding** - Show the magic immediately
3. **Soft paywalls** - Gentle nudges, never blocking critical features
4. **Engagement triggers** - Convert when users are delighted, not frustrated

## Problem Statement

Current monetization blocks features too early. Users:
- Don't experience cry detection (the WOW moment) before paywall
- Hit hard paywalls that feel aggressive
- Leave before understanding the app's unique value
- Never build habit/trust before being asked to pay

## Solution

Create a generous free experience that:
1. Lets users experience cry detection FULLY for first 7 days
2. Provides 20+ free tracks across all categories (not just 5)
3. Allows full BabyMIM AI personalization to build the profile
4. Soft-gates premium features with "Try Premium" prompts (dismissable)
5. Converts through delight, not frustration

---

## User Stories

### US-001: Extended Free Trial Experience
**As a** new user
**I want** to fully experience the app's core features before deciding to pay
**So that** I understand the value and can make an informed decision

#### Acceptance Criteria
- [ ] AC-US1-01: First 7 days = FULL premium access (no restrictions)
- [ ] AC-US1-02: Trial starts on first app launch, persisted locally
- [ ] AC-US1-03: Gentle countdown shown in Settings ("5 days left of Premium trial")
- [ ] AC-US1-04: Day 5: First soft prompt ("Loving the app? Keep all features for $X/mo")
- [ ] AC-US1-05: Day 7: Trial ends with graceful downgrade to free tier
- [ ] AC-US1-06: Trial status synced to analytics for conversion tracking

### US-002: Generous Free Tier Content
**As a** free user after trial
**I want** enough content to keep using the app daily
**So that** I stay engaged and eventually convert

#### Acceptance Criteria
- [ ] AC-US2-01: Free tier includes 20+ tracks (3-4 per category minimum)
- [ ] AC-US2-02: All categories accessible (not locked behind paywall)
- [ ] AC-US2-03: "Free" badge on free tracks, "Premium" badge on locked tracks
- [ ] AC-US2-04: Free tracks rotate weekly to keep content fresh
- [ ] AC-US2-05: User can favorite/save free tracks permanently

### US-003: Full Cry Detection for Free Users
**As a** free user
**I want** cry detection to work without restrictions
**So that** I can rely on the app during stressful moments

#### Acceptance Criteria
- [ ] AC-US3-01: Cry detection is 100% FREE - never paywalled
- [ ] AC-US3-02: Cry type classification (hunger, tired, pain) works for free
- [ ] AC-US3-03: Auto-play response works with FREE tracks only
- [ ] AC-US3-04: "It Helped!" feedback works for free users
- [ ] AC-US3-05: Basic effectiveness history available (last 7 days)

### US-004: BabyMIM Lite for Free Users
**As a** free user
**I want** the AI to learn my baby's preferences
**So that** recommendations improve over time

#### Acceptance Criteria
- [ ] AC-US4-01: Baby profile creation is FREE (name, age, preferences)
- [ ] AC-US4-02: Basic cry embedding and learning works for free
- [ ] AC-US4-03: "What Works" section shows top 5 effective tracks
- [ ] AC-US4-04: Premium unlocks: full insights, LLM recommendations, predictions
- [ ] AC-US4-05: Gentle upsell: "Unlock AI Insights" button in dashboard

### US-005: Soft Paywall Design
**As a** free user encountering premium features
**I want** gentle, dismissable prompts instead of hard blocks
**So that** I don't feel frustrated or trapped

#### Acceptance Criteria
- [ ] AC-US5-01: Premium content shows preview (blurred artwork, 10s audio preview)
- [ ] AC-US5-02: Tapping premium track shows sheet: "Unlock with Premium" + "Not Now"
- [ ] AC-US5-03: "Not Now" dismisses for 24 hours (no re-prompt on same track)
- [ ] AC-US5-04: Max 2 premium prompts per session (prevent annoyance)
- [ ] AC-US5-05: Emergency features NEVER show paywall (during active cry detection)
- [ ] AC-US5-06: Soft prompts use friendly language ("Discover more" not "Subscribe now")

### US-006: Engagement-Triggered Upgrades
**As a** product owner
**I want** to prompt upgrades at moments of delight
**So that** conversion feels natural, not forced

#### Acceptance Criteria
- [ ] AC-US6-01: After "It Helped!" feedback → "Your baby loves this! Get more like it"
- [ ] AC-US6-02: After 5th cry detection → "You've used cry detection 5 times! Keep unlimited access"
- [ ] AC-US6-03: After creating playlist with premium track → "Add premium tracks to complete your playlist"
- [ ] AC-US6-04: Weekly summary email: "Your baby's week - unlock full insights"
- [ ] AC-US6-05: Milestone celebration: "1 week with [BabyName]! Special offer: 50% off first month"

### US-007: Transparent Upgrade UI
**As a** user considering upgrade
**I want** to clearly see what I'm getting
**So that** I can make an informed decision

#### Acceptance Criteria
- [ ] AC-US7-01: Subscription view shows clear free vs premium comparison
- [ ] AC-US7-02: Current usage shown: "You've used 15/20 free tracks this month"
- [ ] AC-US7-03: Personalized value prop: "Unlock 47 more tracks [BabyName] might love"
- [ ] AC-US7-04: Social proof: "Join 50,000+ parents who upgraded"
- [ ] AC-US7-05: Risk reversal: "7-day money-back guarantee" messaging

### US-008: CarPlay Free Experience
**As a** free user in CarPlay
**I want** core functionality to work
**So that** I can safely soothe my baby while driving

#### Acceptance Criteria
- [ ] AC-US8-01: CarPlay works for free users with free content
- [ ] AC-US8-02: Cry detection + auto-response works in CarPlay (free tracks only)
- [ ] AC-US8-03: Premium tracks show "Premium" label, play 10s preview only
- [ ] AC-US8-04: No intrusive upgrade prompts while driving (safety first!)
- [ ] AC-US8-05: After drive ends: gentle prompt if premium content was skipped

---

## Technical Implementation

### New Files

1. **Services/TrialManager.swift** - 7-day trial tracking
2. **Services/FreemiumGatekeeper.swift** - Content access logic
3. **Services/EngagementTriggerService.swift** - Smart upgrade prompts
4. **Components/SoftPaywallSheet.swift** - Non-aggressive upgrade UI
5. **Components/PremiumBadge.swift** - Visual indicator for premium content
6. **Views/FreePremiumComparisonView.swift** - Side-by-side comparison

### Modified Files

1. **Services/SubscriptionManager.swift** - Add trial logic
2. **Services/ContentLibraryService.swift** - Add free/premium filtering
3. **Views/LibraryView.swift** - Show badges, handle soft paywalls
4. **Views/PlayerView.swift** - Handle premium track playback
5. **Services/CryDetectionService.swift** - Ensure always free
6. **Views/HomeView.swift** - Add trial countdown

### Free Tier Content Rules

```swift
struct FreeTierRules {
    static let trialDurationDays = 7
    static let freeTracksPerCategory = 4
    static let totalFreeTracks = 25
    static let freeEffectivenessHistoryDays = 7
    static let maxUpgradePromptsPerSession = 2
    static let promptCooldownHours = 24

    // ALWAYS FREE - Never paywall
    static let alwaysFreeFeatures = [
        "cry_detection",
        "cry_classification",
        "baby_profile",
        "favorites",
        "basic_effectiveness",
        "carplay_basic"
    ]

    // Premium features
    static let premiumFeatures = [
        "unlimited_content",
        "offline_downloads",
        "full_babyim_insights",
        "llm_recommendations",
        "mood_predictions",
        "advanced_analytics",
        "priority_support"
    ]
}
```

### Engagement Trigger Events

```swift
enum EngagementTrigger {
    case itHelpedFeedback(count: Int)
    case cryDetectionMilestone(count: Int)
    case playlistWithPremium
    case weeklyMilestone(weeks: Int)
    case trialEnding(daysLeft: Int)
    case contentLimitReached
    case favoritesPremiumTrack
}
```

---

## E2E Test Requirements (Maestro)

### Critical Flows to Test

1. **Trial Onboarding Flow**
   - App launch → Trial starts
   - Full premium access during trial
   - Trial countdown visible in settings
   - Graceful downgrade after 7 days

2. **Free Tier Playback Flow**
   - Browse library → See free/premium badges
   - Play free track → Works normally
   - Tap premium track → Soft paywall appears
   - Dismiss paywall → Returns to library

3. **Cry Detection (Always Free) Flow**
   - Enable cry detection as free user
   - Detect cry → Auto-play free track
   - "It Helped!" feedback works
   - Verify no paywalls during detection

4. **Upgrade Conversion Flow**
   - Trigger engagement prompt (5th cry detection)
   - View subscription options
   - Complete purchase
   - Verify premium access

5. **CarPlay Free Experience Flow**
   - Connect CarPlay as free user
   - Browse content → Free tracks playable
   - Premium tracks → Preview only
   - No prompts while driving

---

## Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Trial-to-Paid Conversion | 8-12% | N/A |
| Day 7 Retention (Free) | 40% | N/A |
| Day 30 Retention (Free) | 25% | N/A |
| Cry Detection Usage (Free) | 70% of users | N/A |
| Upgrade Prompt Dismissal Rate | <30% | N/A |

---

## Anti-Patterns to Avoid

1. **NO hard paywalls on core features**
2. **NO upgrade prompts during active cry detection**
3. **NO "you've reached your limit" messages (reframe positively)**
4. **NO forced account creation for basic features**
5. **NO dark patterns (hidden unsubscribe, confusing pricing)**
6. **NO interrupting playback for upgrade prompts**
