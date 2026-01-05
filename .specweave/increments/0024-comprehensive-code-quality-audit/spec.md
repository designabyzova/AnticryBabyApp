---
increment: 0024-comprehensive-code-quality-audit
title: "Comprehensive Code Quality Audit & Remediation"
priority: P0
status: planning
type: bug
created: 2026-01-04
dependencies: []
structure: user-stories
tech_stack:
  detected_from: "project.pbxproj"
  language: "swift"
  framework: "swiftui"
  platform: ["ios"]
---

# FS-024: Comprehensive Code Quality Audit & Remediation

## Problem Statement

The BabyInCarApp codebase needs a systematic audit to identify and fix critical quality issues before major feature development (voice control rework). Recent issues include:

1. **P0 Crashes**: Memory crashes (85MB+ OOM kills), force unwraps causing runtime crashes
2. **P1 Performance**: Main thread blocking, threading violations, audio stuttering
3. **P2 Maintainability**: God classes (1500+ lines), tight coupling, Swift best practices violations

Without addressing these, new features will be built on unstable foundation.

## Success Criteria

- ✅ Zero P0 crashes detected in static analysis
- ✅ Zero P1 threading violations
- ✅ All files under 500 lines (max 1500 with justification)
- ✅ Cyclomatic complexity < 15 per function
- ✅ 100% of force unwraps reviewed and fixed
- ✅ SwiftLint rules passing
- ✅ Code audit report generated with remediation plan

## User Stories

### US-001: P0 Crash Detection & Fix
**Project**: main
**As a** developer, I want to identify and fix all P0 crash sources
**So that** the app doesn't crash in production

**Acceptance Criteria:**
- [ ] AC-US1-01: Static analysis detects all force unwraps (!)
- [ ] AC-US1-02: Memory leak detection identifies unbounded arrays/growth
- [ ] AC-US1-03: All P0 crashes documented with fix plan
- [ ] AC-US1-04: Critical force unwraps replaced with safe optional handling
- [ ] AC-US1-05: Memory leaks fixed (bounds enforcement)

### US-002: P1 Performance Issue Detection
**Project**: main
**As a** developer, I want to identify threading and performance violations
**So that** the app runs smoothly without stuttering

**Acceptance Criteria:**
- [ ] AC-US2-01: Main thread blocking operations detected
- [ ] AC-US2-02: Threading violations (UI updates off main thread) found
- [ ] AC-US2-03: Heavy computation on main thread identified
- [ ] AC-US2-04: Audio processing performance issues detected
- [ ] AC-US2-05: Fixes implemented for critical performance issues

### US-003: Code Maintainability Audit
**Project**: main
**As a** developer, I want to identify maintainability issues
**So that** the codebase is easier to work with

**Acceptance Criteria:**
- [ ] AC-US3-01: Files > 500 lines identified and documented
- [ ] AC-US3-02: God classes (> 1000 lines) flagged
- [ ] AC-US3-03: High cyclomatic complexity functions (> 15) detected
- [ ] AC-US3-04: Tight coupling patterns identified
- [ ] AC-US3-05: Swift best practices violations documented

### US-004: SwiftLint Integration & Rules
**Project**: main
**As a** developer, I want SwiftLint enforcing code quality
**So that** future code follows best practices automatically

**Acceptance Criteria:**
- [ ] AC-US4-01: SwiftLint installed and configured (.swiftlint.yml)
- [ ] AC-US4-02: Core rules enabled (force unwraps, line length, etc.)
- [ ] AC-US4-03: Baseline established for existing violations
- [ ] AC-US4-04: CI integration added (Xcode build phase)
- [ ] AC-US4-05: All new code passes SwiftLint

### US-005: Automated Code Quality Report
**Project**: main
**As a** PM, I want a comprehensive quality report
**So that** I can prioritize remediation work

**Acceptance Criteria:**
- [ ] AC-US5-01: Report generated with all P0/P1/P2 issues
- [ ] AC-US5-02: Issues categorized by severity and impact
- [ ] AC-US5-03: Remediation effort estimates included
- [ ] AC-US5-04: Before/after metrics tracked
- [ ] AC-US5-05: Report saved to reports/code-quality-audit.md

## Out of Scope

- Rewriting entire codebase (focus on critical issues)
- Migrating to new architecture (that's a separate increment)
- UI/UX improvements (only code quality)
- Adding new features (audit only)

## Dependencies

- Xcode Instruments (for memory profiling)
- SwiftLint (for static analysis)
- LLM-judge validation (for automated review)

## Estimated Effort

- Investigation: 4 hours (automated tools + LLM analysis)
- Critical fixes: 8 hours (P0 crashes, P1 performance)
- SwiftLint setup: 2 hours (config + CI integration)
- Reporting: 2 hours (document findings + plan)
- **Total: ~16 hours (2 days)**

## Verification Plan

1. **Pre-audit Baseline**:
   - Run SwiftLint (capture violations count)
   - Run Instruments (memory profiling)
   - Document current crash rate from logs

2. **Post-audit Validation**:
   - SwiftLint violations reduced by 80%
   - Zero P0 crashes in static analysis
   - Memory profiling shows stable usage (<50MB)
   - All tests still passing

3. **Success Metrics**:
   - Crash-free rate improvement
   - SwiftLint compliance percentage
   - Code complexity reduction
