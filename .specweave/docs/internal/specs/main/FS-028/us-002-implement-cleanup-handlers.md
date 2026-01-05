# US-002: Implement Cleanup Handlers in All Services

**Feature**: FS-028
**Project**: main
**Priority**: P0
**Estimate**: 8 hours
**Status**: planned

## User Story

**As a** system managing memory
**I want** all services to respond to cleanup notifications
**So that** memory is actually freed when warnings occur

## Acceptance Criteria

- [ ] **AC-US2-01**: AudioEngine implements cleanup handler reducing audio buffers
  - Priority: P0
  - Testable: Yes (memory measurement before/after)
  - Expected reduction: Release all non-playing track buffers (10-30MB)

- [ ] **AC-US2-02**: SmartEmergencyQueue implements cleanup handler releasing queued tracks
  - Priority: P0
  - Testable: Yes (queue size reduction verified)
  - Expected reduction: Keep only current+1 track loaded (8-15MB)

- [ ] **AC-US2-03**: BabyMoodLLMEngine implements cleanup handler trimming history
  - Priority: P0
  - Testable: Yes (history array size verified)
  - Expected reduction: Trim sessionHistory to 20 entries (was 100)

- [ ] **AC-US2-04**: AdaptiveLearningEngine implements cleanup handler
  - Priority: P0
  - Testable: Yes (feature vector count verified)
  - Expected reduction: Trim to 30 feature vectors (was 100)

- [ ] **AC-US2-05**: CryDetectionService implements cleanup handler
  - Priority: P0
  - Testable: Yes (buffer sizes verified)
  - Expected reduction: Clear deepInfantBuffer, reduce FFT window

- [ ] **AC-US2-06**: All handlers respond to both "critical" and "emergency" levels
  - Priority: P0
  - Testable: Yes (notification userInfo level checked)

## Implementation Pattern

All 6 services use this standardized pattern:

```swift
// MARK: - Memory Cleanup Handler

private var cleanupObserver: NSObjectProtocol?

private func setupMemoryCleanupObserver() {
    cleanupObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("MemoryCleanupRequested"),
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let level = notification.userInfo?["level"] as? String else { return }
        Task { @MainActor in
            self?.handleMemoryCleanup(level: level)
        }
    }
}

private func handleMemoryCleanup(level: String) {
    switch level {
    case "critical":
        performCriticalCleanup()
    case "emergency":
        performEmergencyCleanup()
    default:
        break
    }
}

deinit {
    if let observer = cleanupObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

## Per-Service Cleanup Strategies

| Service | Critical Cleanup | Emergency Cleanup |
|---------|-----------------|-------------------|
| AudioEngine | Release non-playing buffers | Release ALL except current |
| SmartEmergencyQueue | Keep current+2 tracks | Keep current+1 track |
| BabyMoodLLMEngine | Trim history to 50 | Trim history to 20 |
| AdaptiveLearningEngine | Trim vectors to 50 | Trim vectors to 30 |
| CryDetectionService | Clear deepInfant buffer | + Disable ML temporarily |

## Related Tasks

- T-003: Add cleanup handler to AudioEngine
- T-004: Add cleanup handler to SmartEmergencyQueue
- T-005: Add cleanup handler to BabyMoodLLMEngine
- T-006: Add cleanup handler to AdaptiveLearningEngine
- T-007: Add cleanup handler to CryDetectionService
- T-008: Add cleanup handler to SmartCryResponseEngine
