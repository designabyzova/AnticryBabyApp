---
increment: 0026-auto-enable-listening-emergency
status: planned
estimated_tasks: 5
estimated_hours: 1-2
---

# Implementation Tasks

## Phase 1: Fix Emergency Activation

### T-001: Update activate() to enable AI monitoring
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US2-01 | **Status**: [x] completed

**Description**: Modify `EmergencyCryStopService.activate(for:)` to automatically call `enableAIMonitoring()` if not already enabled.

**Test**:
- **Given** user taps emergency stop cry button and AI monitoring is not active
- **When** `activate(for: baby)` is called
- **Then** `enableAIMonitoring(for: baby)` is called automatically AND `isAIMonitoringEnabled` becomes `true`

**Implementation**:
1. Read [AIRecommendationEngine.swift:605-617](BabyInCarApp/BabyInCarApp/Services/AIRecommendationEngine.swift#L605-L617)
2. Add check: `if !isAIMonitoringEnabled`
3. Call `try? await enableAIMonitoring(for: baby)` inside the Task block
4. Ensure error handling doesn't crash if permission denied

**Files**:
- `BabyInCarApp/BabyInCarApp/Services/AIRecommendationEngine.swift:605-617`

**Estimated Time**: 15 minutes

---

### T-002: Add unit tests for activate() monitoring
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03 | **Status**: [x] completed

**Description**: Create unit tests to verify `activate()` enables AI monitoring automatically.

**Test**:
- **Given** `EmergencyCryStopService` with `isAIMonitoringEnabled = false`
- **When** `activate(for: baby)` is called
- **Then** `isAIMonitoringEnabled` becomes `true` AND `CryDetectionService.isMonitoring` becomes `true`

**Implementation**:
1. Create test file `EmergencyActivationTests.swift` or add to existing test file
2. Add test: `testActivateEnablesAIMonitoring()`
3. Mock `CryDetectionService` if needed
4. Verify `isAIMonitoringEnabled` flag is set
5. Verify `startMonitoring()` was called

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Services/EmergencyActivationTests.swift` (new or existing)

**Estimated Time**: 20 minutes

---

## Phase 2: Prevent Duplicate Monitoring

### T-003: Test duplicate monitoring prevention
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04 | **Status**: [x] completed

**Description**: Verify that calling `activate()` when monitoring is already enabled doesn't create duplicate services.

**Test**:
- **Given** AI monitoring is already enabled (`isAIMonitoringEnabled = true`)
- **When** user taps emergency button (`activate()` called)
- **Then** `enableAIMonitoring()` is NOT called again AND only one `CryDetectionService` instance exists

**Implementation**:
1. Add test: `testActivateDoesNotDuplicateMonitoring()`
2. Enable AI monitoring first
3. Call `activate(for: baby)`
4. Verify `enableAIMonitoring()` not called again (check call count)
5. Verify `CryDetectionService` not re-initialized

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Services/EmergencyActivationTests.swift`

**Estimated Time**: 15 minutes

---

## Phase 3: Integration Testing

### T-004: Integration test for emergency activation flow
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-US1-04, AC-US1-05, AC-US2-02, AC-US2-03 | **Status**: [x] completed

**Description**: Create integration test for full emergency activation with monitoring.

**Test**:
- **Given** app is idle
- **When** user taps emergency button
- **Then** emergency sounds play AND cry detection is active AND UI shows "AI Monitoring Active"

**Implementation**:
1. Create integration test `EmergencyWithMonitoringIntegrationTests.swift`
2. Test full activation flow:
   - Call `EmergencyCryStopService.activate(for: baby)`
   - Verify `SmartCryResponseEngine.isActive == true`
   - Verify `CryDetectionService.isMonitoring == true`
   - Verify `currentPhase == .attention`
3. Test deactivation:
   - Call `deactivate()`
   - Verify emergency sounds stop
   - Verify monitoring continues (doesn't stop)

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Integration/EmergencyWithMonitoringIntegrationTests.swift` (new)

**Estimated Time**: 25 minutes

---

## Phase 4: Manual Testing & Validation

### T-005: Manual testing and validation
**User Story**: US-001, US-002 | **Satisfies ACs**: All | **Status**: [x] completed

**Description**: Perform comprehensive manual testing of emergency activation with AI monitoring.

**Test**:
- **Given** all code changes implemented
- **When** running manual test scenarios
- **Then** both buttons work consistently and monitoring is active

**Implementation**:
1. Build app in Xcode
2. Manual test scenarios:
   - **Scenario A**: App idle → Tap emergency button → Verify monitoring icon shows → Play baby cry sound → Verify detection works
   - **Scenario B**: Enable AI monitoring first → Tap emergency button → Verify no errors → Verify sounds play
   - **Scenario C**: Emergency active → Deactivate → Verify monitoring continues
   - **Scenario D**: Deny microphone permission → Tap emergency → Verify error message shown, app doesn't crash
3. Check console logs for any errors or warnings
4. Verify UI status displays correctly
5. Test on physical device if available

**Files**:
- Manual testing checklist (this task)

**Estimated Time**: 20 minutes

---

## Summary

**Total Tasks**: 5
**Estimated Time**: 1-2 hours
**Priority**: P0 (Critical Bug Fix)

**Task Breakdown**:
- Phase 1 (Fix): 2 tasks, 35 minutes
- Phase 2 (Duplicate Prevention): 1 task, 15 minutes
- Phase 3 (Integration): 1 task, 25 minutes
- Phase 4 (Manual Testing): 1 task, 20 minutes

**Success Criteria**:
- [x] All 5 tasks completed
- [x] All unit and integration tests passing
- [x] Both emergency and AI detection buttons enable monitoring
- [x] No duplicate service instances
- [x] Manual testing confirms expected behavior
- [x] Ready for production deployment
