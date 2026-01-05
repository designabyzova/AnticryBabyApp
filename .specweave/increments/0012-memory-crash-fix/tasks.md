# Tasks for FS-012: Memory Crash Fix

## Implementation Tasks

### T-001: Analyze CryPatternTracker memory usage
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
**Test**: Given CryPatternTracker code → When analyzing arrays → Then identify unbounded intensitySamples
**Implementation**: Identified `CryBurst.intensitySamples` as unbounded - grows indefinitely during long crying

### T-002: Add maxIntensitySamplesPerBurst constant
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02 | **Status**: [x] completed
**Test**: Given CryPatternTracker → When checking configuration → Then maxIntensitySamplesPerBurst = 200
**Implementation**: Added `private let maxIntensitySamplesPerBurst = 200` with documentation

### T-003: Implement sliding window for intensity samples
**User Story**: US-001 | **Satisfies ACs**: AC-US1-02, AC-US1-03 | **Status**: [x] completed
**Test**: Given burst with >200 samples → When adding new sample → Then oldest samples removed
**Implementation**: Added removal logic in handleCryingFrame() to maintain sliding window

### T-004: Verify all other services have proper bounds
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04 | **Status**: [x] completed
**Test**: Given all audio services → When checking array bounds → Then all have proper limits
**Implementation**: Verified 9 services all have proper bounds - no other memory leaks found

### T-005: Test syntax and verify compilation
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04 | **Status**: [x] completed
**Test**: Given modified code → When running swiftc -parse → Then no errors
**Implementation**: Syntax check passed successfully
