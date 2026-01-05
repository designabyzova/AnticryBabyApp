# FS-011: Emergency Cry-Stop Intelligence Fix

## Problem Statement

The Emergency Cry-Stop button currently plays the SAME hardcoded sound every time regardless of:
- Baby's cry type (hunger, tired, pain, etc.)
- Baby's learned preferences
- Historical effectiveness data
- ML recommendations

The sophisticated SmartCryResponseEngine with 4-level intelligent sound selection is NEVER called because:
1. `isAIMonitoringEnabled` defaults to `false`
2. `useSmartResponse` defaults to `false`
3. The activation path falls through to dumb hardcoded sounds

## Solution

Make the Emergency Cry-Stop button ALWAYS use intelligent sound selection, even without pre-enabling AI monitoring.

## User Stories

### US-001: Intelligent Emergency Response Without Pre-Configuration
**As a** parent tapping the emergency button
**I want** the app to immediately use intelligent sound selection
**So that** my baby gets the most effective calming sound without me needing to configure anything first

**Acceptance Criteria:**
- [x] AC-US1-01: Emergency button tap triggers SmartCryResponseEngine by default
- [x] AC-US1-02: If no cry detection data available, use age-appropriate intelligent defaults
- [x] AC-US1-03: Historical effectiveness data is checked even without active monitoring
- [x] AC-US1-04: Sound selection varies based on baby's profile (age, preferences)
- [x] AC-US1-05: Fallback to random selection from top 5 effective sounds (not single hardcoded)

### US-002: Adaptive Sound Rotation
**As a** parent using emergency mode multiple times
**I want** the app to try different effective sounds
**So that** my baby doesn't habituate to a single sound

**Acceptance Criteria:**
- [x] AC-US2-01: Consecutive emergency activations use different sounds
- [x] AC-US2-02: Sound rotation prioritizes historically effective sounds
- [x] AC-US2-03: If current sound isn't working (30s), automatically try next best option
- [x] AC-US2-04: Track which sounds were tried in current session

### US-003: Learning Without Explicit Monitoring
**As a** parent
**I want** the app to learn from my "Baby is Calm" feedback
**So that** future emergency activations are more effective

**Acceptance Criteria:**
- [x] AC-US3-01: "Baby is Calm" button records effectiveness to AdaptiveLearningEngine
- [x] AC-US3-02: Time-to-calm metric is tracked per sound type
- [x] AC-US3-03: Next emergency activation considers this learning
- [x] AC-US3-04: Learning persists across app sessions

## Technical Approach

### Change 1: EmergencyCryStopService.activate()
Remove the condition that requires `isAIMonitoringEnabled`. Always use SmartCryResponseEngine.

### Change 2: SmartCryResponseEngine fallback
When no cry detection data is available, still use intelligent selection based on:
1. Baby age
2. Historical effectiveness (from previous sessions)
3. Random selection from top sounds (not single hardcoded)

### Change 3: Sound rotation
Track recently played sounds and avoid repetition.

## Out of Scope
- Changes to AI Monitoring feature
- Changes to background cry detection
- CarPlay emergency button (will inherit fix automatically)
