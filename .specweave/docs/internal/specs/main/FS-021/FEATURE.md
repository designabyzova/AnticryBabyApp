# FS-021: Emergency Systems Consolidation

**Status**: Planned  
**Priority**: P1  
**Type**: Refactor  
**Increment**: 0021-emergency-systems-consolidation  
**Created**: 2026-01-04  
**Estimated Effort**: 1-2 weeks

## Overview

**Problem Statement**: The codebase has duplicate emergency queue implementations causing developer confusion, maintenance burden, and potential bugs. Two parallel systems exist:
- **SmartQueue** (Active): SmartQueueView (1091 lines) + SmartEmergencyQueue (1185 lines) - Production system
- **EmergencyQueue** (Legacy): EmergencyQueueView (153 lines) + EmergencyQueueManager (291 lines) - Unused legacy code

**Business Value**:
- Eliminate developer confusion (single source of truth)
- Reduce maintenance burden (~720 lines of redundant code)
- Improve code reliability and clarity
- Ensure consistent emergency response UX

## Architecture

**Current State**:
```
CryDetectionView.swift
  └─> SmartQueueView (line 91) ✅ PRODUCTION
      └─> SmartEmergencyQueue.shared

SmartCryResponseEngine.swift
  └─> EmergencyQueueManager (line 44) ⚠️ LEGACY (unused in production)
```

**Target State**:
```
CryDetectionView.swift
  └─> SmartQueueView ✅ ONLY SYSTEM
      └─> SmartEmergencyQueue.shared (canonical)
```

## User Stories

- [US-001: Deprecate Legacy EmergencyQueueManager](us-001-deprecate-legacy-emergencyqueuemanager.md)
- [US-002: Deprecate Legacy EmergencyQueueView](us-002-deprecate-legacy-emergencyqueueview.md)
- [US-003: Verify AI Cry Detection Integration](us-003-verify-ai-cry-detection-integration.md)
- [US-004: Update Tests for Consolidated System](us-004-update-tests-for-consolidated-system.md)
- [US-005: Documentation and Code Cleanup](us-005-documentation-and-code-cleanup.md)

## Architecture Decision Records

- [ADR-0125: Deprecation vs Deletion Strategy](../../architecture/adr/0125-deprecation-vs-deletion-strategy.md)
- [ADR-0126: SmartQueue as Canonical Emergency System](../../architecture/adr/0126-smartqueue-canonical-system.md)
- [ADR-0127: Test Migration Strategy](../../architecture/adr/0127-test-migration-strategy.md)

## Implementation Plan

See [plan.md](../../../../increments/0021-emergency-systems-consolidation/plan.md) for detailed implementation phases.

**Phases**:
1. Code Deprecation (Day 1) - Add @available annotations
2. Production Reference Cleanup (Day 2) - Remove EmergencyQueueManager from SmartCryResponseEngine
3. Test Migration (Days 3-4) - Update snapshot and unit tests
4. E2E Verification (Day 5) - Run Maestro flows
5. Documentation (Days 5-6) - Update CLAUDE.md and specs

## Success Criteria

- ✅ All legacy code marked with @available(*, deprecated)
- ✅ Zero production references to EmergencyQueueManager
- ✅ All tests migrated to SmartQueue mocks
- ✅ E2E Maestro flows pass
- ✅ Documentation updated
- ✅ Code coverage maintained at ≥80%

## Related Features

- FS-015: Science-Based Cry Intelligence
- FS-017: Smart Emergency Playlists

